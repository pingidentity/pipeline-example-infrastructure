#!/usr/bin/env sh
set -e

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

## try to minimize extended crashloops but also enough time to deploy
##TODO improve error watching
_timeout=600
test "${pingdirectorySha}" = "${CURRENT_SHA}" && _timeout=1200
test ! "$(helm history "${RELEASE}")" && _timeout=900

## DELETE ONCE VAULT IS WORKING
## Getting Client ID+Secret for this app.
getPfClientAppInfo

VALUES_FILE=${VALUES_FILE:=k8s/values.yaml}
VALUES_DEV_FILE=${VALUES_DEV_FILE:=k8s/values.dev.yaml}
test -n "${K8S_CLUSTER}" && VALUES_REGION_FILE="k8s/@values.${K8S_CLUSTER}.yaml"

## envsubst all the things
export RELEASE
expandFiles "${K8S_DIR}"
if test "${K8S_NAMESPACE}" = "${DEV_NAMESPACE}" ; then
  _valuesDevFile="-f ${VALUES_DEV_FILE}"
fi

## Deploy any relevant k8s manifests
applyManifests "${MANIFEST_DIR}/splunk-config" "${MANIFEST_DIR}/secrets/${K8S_NAMESPACE}" $_dryRun

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
  -f "${VALUES_FILE}" ${_valuesDevFile} \
  --namespace "${K8S_NAMESPACE}" --version "${CHART_VERSION}" $_dryRun

if test -n $_dryRun ; then 
  _timeoutElapsed=0
  readyCount=0
  while test ${_timeoutElapsed} -lt ${_timeout} ; do
    sleep 
    if test $(kubectl get pods -l app.kubernetes.io/instance="${RELEASE}" -n "${K8S_NAMESPACE}" -o go-template='{{range $index, $element := .items}}{{range .status.containerStatuses}}{{if not .ready}}{{$element.metadata.name}}{{"\n"}}{{end}}{{end}}{{end}}' | wc -l ) = 0 ; then
      readyCount=$(( readyCount+1 ))
      sleep 4
    fi
    _timeoutElapsed=$((_timeoutElapsed+6))
    test ${readyCount} -ge 3 && break
  done

  ## run helm diff to show what will change to help identify errors
  if test "${?}" -ne 0 ; then
    ## helm diff to see what changed and could have cause error.
    revCurrent=$(helm ls --filter "${RELEASE}" -o json | jq -r '.[0].revision')
    revPrevious=$(( revCurrent-1 ))
    helm diff revision "${RELEASE}" $revCurrent $revPrevious
    exit 1
  fi
fi