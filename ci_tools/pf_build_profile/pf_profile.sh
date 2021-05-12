#!/usr/bin/env sh
set -x
_initialDir="${PWD}"
_scriptDir="${PWD}/ci_tools/pf_build_profile"
cd "${_scriptDir}" || exit

test "${1}" == "-B" && _backup=true

prop() {
  grep "${1}" env.properties|cut -d'=' -f2
}
# shellcheck source=../ci_tools.lib.sh
. ../ci_tools.lib.sh
set +a
set -x

getPfVars

pVersion="$(git rev-parse --short HEAD)"

echo "Creating output folder..."
mkdir -p "${pVersion}"
export pVersion

echo "Downloading config from ${PF_ADMIN_PUBLIC_HOSTNAME}..."
curl -X GET --basic -u Administrator:${PING_IDENTITY_PASSWORD} --header 'Content-Type: application/json' --header 'X-XSRF-Header: PingFederate' "https://${PF_ADMIN_PUBLIC_HOSTNAME}/pf-admin-api/v1/bulk/export" --insecure | jq -r > "${pVersion}/data.json"

echo "Creating/modifying ${pVersion}/env_vars and ${pVersion}/data.json.subst..."
java -jar bulk-config-tool.jar pf-config.json "${pVersion}/data.json" "${pVersion}/env_vars" "${pVersion}/data.json.subst" > "${pVersion}/export-convert.log"

getGlobalVars | awk '{ print length($0) " " $0; }' | sort -r -n | cut -d ' ' -f 2- > tmpHosts
./variablize.sh -p "${pVersion}/data.json.subst" -e tmpHosts -B
echo "#### GLOBAL ENV VARS #####" >> "${pVersion}/env_vars"
cat tmpHosts >> "${pVersion}/env_vars"
rm tmpHosts
if test -f hosts ; then
  ./variablize.sh -p "${pVersion}/data.json.subst" -e hosts
  echo "#### HOSTS FILE VARS #####" >> "${pVersion}/env_vars"
  cat hosts >> "${pVersion}/env_vars"
fi

mv "${pVersion}/env_vars" "${pVersion}/tmp_env_vars"
sed 's/=.*$/=/' "${pVersion}/tmp_env_vars" > "${pVersion}/env_vars"
cp -f "${pVersion}/env_vars" "vars_diff"

cd "${_initialDir}" || exit
cp "${_scriptDir}/${pVersion}/data.json.subst" "profiles/pingfederate_admin/instance/bulk-config/data.json.subst"
test ! $_backup && rm -rf "${_scriptDir}/${pVersion}/"