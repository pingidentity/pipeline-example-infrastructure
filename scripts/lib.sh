#!/usr/bin/env sh
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Set all Global script variables
#   Every variable set in this section will be exported
set -a
## Determine if this script is being run locally or from a pipeline:
if test -z "${GITHUB_REPOSITORY}"; then
  GITHUB_REPOSITORY=$(git remote get-url origin)
  GITHUB_REPOSITORY="${GITHUB_REPOSITORY##https://github.com/}"
  GITHUB_REF=$(git rev-parse --abbrev-ref HEAD)
  REF="${GITHUB_REF}"
  # shellcheck source=local-secrets.sh
  . "scripts/local-secrets.sh"
fi

## Set Helm chart repo version to use
test -z "${CHART_VERSION}" \
  && CHART_VERSION="0.8.6"

export DEFAULT_BRANCH=prod

## Determine trigger
### This pattern will match if the workflow trigger is a branch
test -z ${REF} \
  && REF=$(echo "${GITHUB_REF}" | sed -e "s#refs/heads/##g")
### This pattern will match if the workflow trigger is a tag
test "${GITHUB_REF}" != "${GITHUB_REF%%"${DEFAULT_BRANCH}"}" \
  && REF=prod

set +a
# End: Set all Global script variables

echo "${REF}"
getGlobalVars() {
  kubectl get cm "${REF}-global-env-vars" -o=jsonpath='{.data}' | jq -r '. | to_entries | .[] | .key + "=" + .value + ""'
}

# prep for expandFiles
getEnvKeys() {
    env | cut -d'=' -f1 | sed -e 's/^/$/'
}

# process all files that end in .subst to hardcoded files for deployment
envsubstFiles() {
    while true ; do
      test -z "${1}" && break
      _expandPath="${1}"
      echo "  Processing templates"

      find "${_expandPath}" -type f -iname "*.subst" > tmpFileList
      while IFS= read -r template; do
          echo "    t - ${template}"
          _templateDir="$(dirname ${template})"
          _templateBase="$(basename ${template})"
          envsubst "'$(getEnvKeys)'" < "${template}" > "${_templateDir}/${_templateBase%.subst}"
          echo "${_templateDir}/${_templateBase%.subst}" >> expandedFiles
      done < tmpFileList
      rm tmpFileList
      shift
    done
}

# for cleanup on local when not dry-run
cleanExpandedFiles() {
  while IFS= read -r file; do
    rm "${file}"
  done < expandedFiles
  rm expandedFiles
}