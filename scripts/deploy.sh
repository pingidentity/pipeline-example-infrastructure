#!/usr/bin/env sh
CWD=$(dirname "$0")

usage ()
{
cat <<END_USAGE
Usage:  {options} 
    * - required
    where {options} include:
    --verbose|-v
        Use verbose output
    --dry-run|-d
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
while ! test -z ${1} ; do
  case "${1}" in
    --dry-run|-d)
      export _dryRun="--dry-run" ;;
    --verbose|-v)
      set -x ;;
    -h|--help)
      exit_usage "./scripts/deploy.sh --dry-run";;
    *)
      exit_usage "Unrecognized Option ${1}" ;;
  esac
  shift
done

# Source global functions and variables
. "${CWD}/lib.sh"

# builds sha for each product based on the folder name in ./profiles/* (e.g. pingfederateSha)
#   this determines what will be rolled. 
for D in ./profiles/* ; do 
  if [ -d "${D}" ]; then 
    _prodName=$(basename "${D}" | sed 's/-/_/' | tr '[:lower:]' '[:upper:]')
    dirr="${D}"
    set -a
    eval "${_prodName}_SHA=sha-$(git log -n 1 --pretty=format:%h -- "$dirr")"
    set +a
  fi
done

# Convert .subst files to hardcoded files for deployment
envsubstFiles "helm" "manifest"

# START: Deploy

## Apply all evaluated kubernetes manifest files
find "manifest" -type f -regex ".*yaml$" >> k8stmp
while IFS= read -r k8sFile; do
  kubectl apply -f "$k8sFile" $_dryRun -o yaml
done < k8stmp
test -z "${_dryRun}" && rm k8stmp

## Identify possible values.yaml files
VALUES_FILE=${VALUES_FILE:=helm/values.yaml}
VALUES_DEV_FILE=${VALUES_DEV_FILE:=helm/values.dev.yaml}
test "${REF}" != "prod" && _valuesDevFile="-f ${VALUES_DEV_FILE}"

## Helm Deploy
helm upgrade --install \
  "${REF}" pingidentity/ping-devops \
  -f "${VALUES_FILE}" ${_valuesDevFile}  \
  --version "${CHART_VERSION}" $_dryRun

## For Statefulsets that failed previously, the crashing pod is deleted to pick up new changes
##    this is per: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#forced-rollback
##
## Also, some crashing pods may not have been properly labeled previously.
_podList=$(kubectl get pod --selector=crashloop=true -o jsonpath='{..metadata.name}')

kubectl delete pod $(printf "%s " $_podList) --force --grace-period=0 "${_dryRun}"

# Finish by cleaning up hardcoded files if not a dry-run
test -z "${_dryRun}" && cleanExpandedFiles

# END: Deploy

# START: Watch Deployment Health

if test -z $_dryRun ; then 
  ## Set to maximum time for a successful deploy
  _timeout=3600
  _timeoutElapsed=0
  _readyCount=0

  ## Collect previous helm release info to show in case of failure
  revCurrent=$(helm ls --filter "${REF}" -o json | jq -r '.[0].revision')
  revPrevious=$(( revCurrent-1 ))
  test ! -d tmp && mkdir tmp
  helm diff revision "${REF}" $revCurrent $revPrevious --no-color > tmp/helmdiff.txt

  ## Watch helm release for pods going to crashloop
  while test ${_timeoutElapsed} -lt ${_timeout} ; do
    sleep 6
    if test $(kubectl get pods -l app.kubernetes.io/instance="${REF}" -n "${K8S_NAMESPACE}" -o go-template='{{range $index, $element := .items}}{{range .status.containerStatuses}}{{if not .ready}}{{$element.metadata.name}}{{"\n"}}{{end}}{{end}}{{end}}' | wc -l ) = 0 ; then
      _readyCount=$(( _readyCount+1 ))
      sleep 4
    else 
      _crashingPods=$(kubectl get pods -l app.kubernetes.io/instance="${REF}" -n "${K8S_NAMESPACE}" -o go-template='{{range $index, $element := .items}}{{range .status.containerStatuses}}{{if gt .restartCount 2 }}{{$element.metadata.name}}{{"\n"}}{{end}}{{end}}{{end}}')
      numCrashing=$(echo "${_crashingPods}" |wc -c)
      ## Recognize failed release via extended crashloop
      if test $numCrashing -ge 3 ; then
        echo "${RED}ERROR: Found pods crashing. Adding label 'crashloop=true'"
        echo "${RED}$_crashingPods"
        for _pod in $_crashingPods
        do
          kubectl label pod "$_pod" crashloop=true
        done
        _timeoutElapsed=$(( _timeout+1 ))
      fi
    fi
    if test ${_readyCount} -ge 3 ; then
      echo "${GREEN}INFO: Successfully Deployed.${NC}"
      exit 0
    fi
    _timeoutElapsed=$((_timeoutElapsed+6))
  done

  ## Getting this far is an error
  ##   show what changed to help identify errors
  if test ${_timeoutElapsed} -ge ${_timeout} ; then

    cat tmp/helmdiff.txt
    set +x
    echo "${RED}ERROR: when deploying release${NC}"
    exit 1
  fi
fi