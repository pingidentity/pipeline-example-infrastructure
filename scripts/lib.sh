#!/usr/bin/env sh

CWD=$(dirname "$0")

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
  . "${CWD}/local-secrets.sh"
fi

## Existing export env variables will not be overwritten. Thus test -z ${VARIABLE_NAME}. 
##   This allows variables to be set before the script for local testing

## Eval Server profile url from github variable
test -z "${SERVER_PROFILE_URL}" \
  && SERVER_PROFILE_URL="https://github.com/${GITHUB_REPOSITORY}"
## Set Domain for Ingress
test -z "${DEFAULT_DOMAIN}" \
  && DEFAULT_DOMAIN="ping-devops.com"
## Set Helm chart repo version to use
test -z "${CHART_VERSION}" \
  && CHART_VERSION="0.8.6"

## Determine trigger
### This pattern will match if the workflow trigger is a branch
test -z ${REF} \
  && REF=$(echo "${GITHUB_REF}" | sed -e "s#refs/heads/##g")
### This pattern will match if the workflow trigger is a tag
test "${GITHUB_REF}" != "${GITHUB_REF##refs/tags}" \
  && REF=prod \
  && TAG="${GITHUB_REF##refs/tags}"
### Environment specific variables
case "${REF}" in
  prod )
    FOO=prod
    ;;
  * )
    FOO="${REF}"
    ;;
esac

set +a
# End: Set all Global script variables


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