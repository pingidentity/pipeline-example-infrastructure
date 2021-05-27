#!/usr/bin/env sh

test -z "${REF}" && REF=$(git rev-parse --abbrev-ref HEAD)
set -a
# shellcheck source=@localSecrets
test -f ./ci_tools/@localSecrets && . ./ci_tools/@localSecrets

## CI VARIABLES
CHART_VERSION="0.6.2"
DEV_NAMESPACE=${K8S_NAMESPACE:-cicd-dev}
QA_NAMESPACE=${K8S_NAMESPACE:-cicd-qa}
PROD_NAMESPACE=${K8S_NAMESPACE:-cicd-prod}
VALUES_FILE=${VALUES_FILE:=k8s/values.yaml}
VALUES_DEV_FILE=${VALUES_DEV_FILE:=k8s/values.dev.yaml}
K8S_DIR=k8s
CURRENT_SHA=$(git log -n 1 --pretty=format:%h)

case "${REF}" in
  qa )
    RELEASE=${RELEASE:=qa} 
    K8S_NAMESPACE="${QA_NAMESPACE}"
    ;;
  prod ) 
    RELEASE=${RELEASE:=prod}
    K8S_NAMESPACE="${PROD_NAMESPACE}"
    ;;
  * )
    RELEASE="${REF}"
    K8S_NAMESPACE="${DEV_NAMESPACE}" 
    ;;
esac

kubectl config set-context --current --namespace="${K8S_NAMESPACE}"

getGlobalVars() {
  kubectl get cm "${RELEASE}-global-env-vars" -o=jsonpath='{.data}' -n "${K8S_NAMESPACE}" | jq -r '. | to_entries | .[] | .key + "=" + .value + ""'
}

getPfVars() {
export PF_ADMIN_PUBLIC_HOSTNAME=$(kubectl get ing -l app.kubernetes.io/instance=${RELEASE},app.kubernetes.io/name=pingfederate-admin -o=jsonpath='{.items[0].spec.rules[0].host}')
PING_IDENTITY_PASSWORD="2FederateM0re"
}

createGlobalVarsPostman() {
  # kubectl get cm "${RELEASE}-global-env-vars" -o=jsonpath='{.data}' -n "${K8S_NAMESPACE}" | jq -r '. | to_entries | .[] | .key + "=" + .value + ""'
  data=$(kubectl get cm "${RELEASE}-global-env-vars" -n "${K8S_NAMESPACE}" -o=jsonpath='{.data}')
  keys=$(echo "$data" | jq -r '. | to_entries | .[] | .key')
  varEntries=""
  for key in $keys ; do
    value=$(echo "${data}" | jq -r ".${key}" )
    varEntries="${varEntries} { \"key\": \"${key}\", \"value\": \"${value}\" },"
  done
  varEntries=${varEntries%?}
  cat << EOF | kubectl apply -f -
  apiVersion: v1
  data:
    global_postman_vars.json: |
      {
        "id": "eae83fc1-25de-4def-9062-7dc2ba993710",
        "name": "myping",
        "values": [
          ${varEntries}
        ],
        "_postman_variable_scope": "global"
      }
  kind: ConfigMap
  metadata:
    annotations:
      use-subpath: "true"
    name: ${RELEASE}-global-env-vars-postman
    namespace: ${K8S_NAMESPACE}
EOF
}

getPfClientAppInfo(){
  # get bearer token (login). 
  p1Token=$(curl -sS --location -u "${PF_ADMIN_WORKER_ID}:${PF_ADMIN_WORKER_SECRET}" --request POST "https://auth.pingone.com/${P1_ADMIN_ENV_ID}/as/token" \
    --header 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode 'grant_type=client_credentials' | jq -r ".access_token")
  # get client app and secret
  pfEnvClientId=$(curl -sS --location --request GET "https://api.pingone.com/v1/environments/${P1_ADMIN_ENV_ID}/applications" \
    --header "Authorization: Bearer ${p1Token}" \
    | jq -r "._embedded.applications[] | select(.name==\"${RELEASE}-pf-admin\") | .id")
  pfEnvClientSecret=$(curl -sS --location --request GET "https://api.pingone.com/v1/environments/${P1_ADMIN_ENV_ID}/applications/${pfEnvClientId}/secret" \
    --header "Authorization: Bearer ${p1Token}" \
    | jq -r '.secret')
}