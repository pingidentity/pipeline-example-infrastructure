#!/usr/bin/env sh

# Set all Global script variables
#   Every variable in this env should be exported

## Default branch of repo
export DEFAULT_BRANCH=prod
export HELM_CHART_NAME="pingidentity/ping-devops"
export HELM_CHART_URL="https://helm.pingidentity.com/"
export CHART_VERSION="0.9.0"
## Useful for multiple pipelines in same clusters
##  Prefixes ENV variable. ENV variable is used for helm release name.
##  If used, include trailing slash. (e.g. ENV_PREFIX="myenv-")
export ENV_PREFIX=""
