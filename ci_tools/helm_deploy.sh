#!/usr/bin/env sh

set -x
set -e

set -a
# shellcheck source=./ci_tools.lib.sh
. ./ci_tools/ci_tools.lib.sh

if test "${1}" == "--dry-run" || test "${1}" == "-d" ; then
  _dryRun="--dry-run"
fi

## builds sha for each product based on the folder name in ./profiles/* (e.g. pingfederateSha)
  ## this determines what will be redeployed. 
for D in ./profiles/* ; do 
  if [ -d "${D}" ]; then 
    _prodName=$(basename "${D}")
    dirr="${D}"
    eval "${_prodName}Sha=x$(git log -n 1 --pretty=format:%h -- "$dirr")"
  fi
done

#try to minimize extended crashloops
_timeout=600
test "${pingdirectorySha}" = "${CURRENT_SHA}" && _timeout=600
test ! "$(helm history "${RELEASE}")" && _timeout=900


export RELEASE
if test "${K8S_NAMESPACE}" = "${DEV_NAMESPACE}" ; then
  envsubst < "${VALUES_DEV_FILE}" > "${VALUES_DEV_FILE}.final"
  _valuesDevFile="-f ${VALUES_DEV_FILE}.final"
fi

envsubst < "${VALUES_FILE}" > "${VALUES_FILE}.final"
_valuesFile="${VALUES_FILE}.final"

# cat $VALUES_FILE

## DELETE ONCE VAULT IS WORKING
## Getting Client ID+Secret for this app.
getPfClientAppInfo

kubectl apply -f "${K8S_DIR}/secrets/${K8S_NAMESPACE}"

# # install the new profiles, but don't move on until install is successfully deployed. 
# # tied to chart version to avoid breaking changes.
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
  --set pingfederate-admin.envs.SERVER_PROFILE_BASE_BRANCH="${REF}" \
  -f "${_valuesFile}" ${_valuesDevFile} \
  --namespace "${K8S_NAMESPACE}" --version "${CHART_VERSION}" $_dryRun

_timeoutElapsed=0
while test ${_timeoutElapsed} -lt ${_timeout} ; do
  sleep 6
  if test $(kubectl get pods -o go-template='{{range $index, $element := .items}}{{range .status.containerStatuses}}{{if not .ready}}{{$element.metadata.name}}{{"\n"}}{{end}}{{end}}{{end}}' | wc -l ) = 0 ; then
      break;
  fi
  _timeoutElapsed=$((_timeoutElapsed+6))
done

test "${?}" -ne 0 && exit 1

test -z "$_dryRun" && helm history "${RELEASE}" --namespace "${K8S_NAMESPACE}"