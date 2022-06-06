#!/usr/bin/env sh

## THIS IS TO CLEAN THE RELEASE RELATED TO YOUR CURRENT BRANCH IN GIT.
## *****IT CAN BE VERY DESTRUCTIVE*****
## Be sure you're on the right git branch. 

# shellcheck source=lib.sh
. ./scripts/lib.sh

helm uninstall "${REF}"
if test "${1}" = "--heavy" ; then
  kubectl delete pvc --selector=app.kubernetes.io/instance="${REF}"
  # kubectl delete ns "${K8S_NAMESPACE}"
fi

echo "${GREEN} INFO: Environment pruned - ${REF} ${NC}"