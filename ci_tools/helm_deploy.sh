#!/usr/bin/env sh

usage ()
{
cat <<END_USAGE
Usage:  {options} 
    * - required
    where {options} include:
    --cluster
        Must be context avaialable in ~/.kube/config
    --dry-run
        Show deployment yamls without appying
END_USAGE
exit 99
}
exit_usage()
{
    echo "$*"
    usage
    exit 1
}

## Gather flags
while ! test -z ${1} ; do
  case "${1}" in
    --cluster|-c)
      shift
      export K8S_CLUSTER="${1}" ;;
    --dry-run|-d)
      export _dryRun="--dry-run" ;;
    --verbose|-v)
      set -x ;;
    -h|--help)
      exit_usage "./ci_tools/helm_deploy.sh --cluster <cluster-name> --dry-run";;
    *)
      exit_usage "Unrecognized Option ${1}" ;;
  esac
  shift
done

set -e
set -a
# shellcheck source=./ci_tools.lib.sh
. ./ci_tools/ci_tools.lib.sh


## builds sha for each product based on the folder name in ./profiles/* (e.g. pingfederateSha)
  ## this determines what will be redeployed. 
for D in ./profiles/* ; do 
  if [ -d "${D}" ]; then 
    _prodName=$(basename "${D}")
    dirr="${D}"
    eval "${_prodName}Sha=x$(git log -n 1 --pretty=format:%h -- "$dirr")"
  fi
done

## envsubst all the things
export RELEASE
expandFiles "${K8S_DIR}"

VALUES_FILE=${VALUES_FILE:=k8s/values.yaml}
VALUES_DEV_FILE=${VALUES_DEV_FILE:=k8s/values.dev.yaml}
VALUES_REGION_FILE="k8s/values.${K8S_CLUSTER}.yaml"
test "${K8S_NAMESPACE}" = "${DEV_NAMESPACE}" && _valuesDevFile="-f ${VALUES_DEV_FILE}"

## DELETE ONCE VAULT IS WORKING
## Getting Client ID+Secret for this app.
getPfClientAppInfo

## Deploy any relevant k8s manifests
applyManifests "${MANIFEST_DIR}/splunk-config" "${K8S_SECRETS_DIR}" $_dryRun

## install the new profiles, but don't move on until install is successfully deployed. 
## tied to chart version to avoid breaking changes.
helm upgrade --install \
  "${RELEASE}" pingidentity/ping-devops \
  --set pingdirectory.envs.PD_PROFILE_SHA="${pingdirectorySha}" \
  --set pingfederate-admin.envs.PF_PROFILE_SHA="${pingfederateSha}" \
  --set pingfederate-admin.envs.PF_ADMIN_PROFILE_SHA="${pingfederate_adminSha}" \
  --set pingfederate-admin.envs.PF_OIDC_CLIENT_ID="${pfEnvClientId}" \
  --set pingfederate-admin.envs.PF_OIDC_CLIENT_SECRET="${pfEnvClientSecret}" \
  --set pingfederate-engine.envs.PF_OIDC_CLIENT_ID="${pfEnvClientId}" \
  --set pingfederate-engine.envs.PF_OIDC_CLIENT_SECRET="${pfEnvClientSecret}" \
  --set pingfederate-engine.envs.PF_PROFILE_SHA="${pingfederateSha}" \
  --set global.envs.SERVER_PROFILE_BRANCH="${REF}" \
  --set global.envs.SERVER_PROFILE_BASE_BRANCH="${REF}" \
  -f "${VALUES_FILE}" -f "${VALUES_REGION_FILE}" ${_valuesDevFile}  \
  --namespace "${K8S_NAMESPACE}" --version "${CHART_VERSION}" $_dryRun

if test -z $_dryRun ; then 
  ## try to minimize extended crashloops but also enough time to deploy
  _timeout=600
    revCurrent=$(helm ls --filter "${RELEASE}" -o json | jq -r '.[0].revision')
    revPrevious=$(( revCurrent-1 ))
    test ! -d tmp && mkdir tmp
    helm diff revision "${RELEASE}" $revCurrent $revPrevious --no-color > tmp/helmdiff.txt
  if test $? -eq 0 ; then
    ## Check if pd changed. 
    sed s/'+  '/'   '/g tmp/helmdiff.txt > tmp/helmdiff.yaml
    sed -i.bak s/'-  '/'   '/g tmp/helmdiff.yaml
    ## If pd change give a lot of time
    export _pdName="${RELEASE}-pingdirectory"
    if test $(yq e '.* | select(.metadata.name == env(_pdName)) | .spec.template.metadata.annotations' tmp/helmdiff.yaml | grep -c checksum/config) -ne 0 ; then
      _timeout=3600
    fi
  else
    ##TODO:tune this for an efficient startup
    _timeout=3600
  fi

  _timeoutElapsed=0
  readyCount=0
  ## watch helm release
  while test ${_timeoutElapsed} -lt ${_timeout} ; do
    sleep 6
    if test $(kubectl get pods -l app.kubernetes.io/instance="${RELEASE}" -n "${K8S_NAMESPACE}" -o go-template='{{range $index, $element := .items}}{{range .status.containerStatuses}}{{if not .ready}}{{$element.metadata.name}}{{"\n"}}{{end}}{{end}}{{end}}' | wc -l ) = 0 ; then
      readyCount=$(( readyCount+1 ))
      sleep 4
    else 
      crashingPods=$(kubectl get pods -l app.kubernetes.io/instance="${RELEASE}" -n "${K8S_NAMESPACE}" -o go-template='{{range $index, $element := .items}}{{range .status.containerStatuses}}{{if gt .restartCount 2 }}{{$element.metadata.name}}{{"\n"}}{{end}}{{end}}{{end}}')
      numCrashing=$(wc -c < "${crashingPods}")
      if test $numCrashing -gt 5 ; then
        echo "ERROR: Found pods crashing $crashingPods"
        _timeoutElapsed=$(( _timeout+1 ))
      fi
    fi
    if test ${readyCount} -ge 3 ; then
      echo "INFO: Successfully Deployed."
      exit 0
    fi
    _timeoutElapsed=$((_timeoutElapsed+6))
  done

  ## Getting this far is an error
  ## show what changed to help identify errors
  if test ${_timeoutElapsed} -ge ${_timeout} ; then
    cat tmp/helmdiff.txt
    test ${_timeoutElapsed} -ge ${_timeout} && echo "ERROR: timed our waiting for deployment" 
    echo "ERROR: when deploying release"
    exit 1
  fi
fi