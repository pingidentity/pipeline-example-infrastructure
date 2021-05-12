#!/usr/bin/env sh
# set -x
set -e
_initialDir="${PWD}"
_scriptDir="${PWD}/ci_tools/pd_build_profile"
cd "${_scriptDir}" || exit

test "${1}" == "-B" && _backup=true

usage ()
{
cat <<END_USAGE
Usage:  {options} 
    NOTE: case-insensitivity is not supported
    where {options} include:
    
    --includeLdif
        Pulls current userRoot Backend
    -B, --backup
        create config.bak for backup
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
    -B|--backup)
      _backup="-B" ;;
    -I|--includeLdif)
      _includeLdif=true ;;

    -h|--help)
      exit_usage "This script pulls a pd.profile from a running {RELEASE}-pingdirectory-0
                   ";;
    *)
      exit_usage "Unrecognized Option" ;;
  esac
  shift
done

prop() {
  grep "${1}" env.properties|cut -d'=' -f2
}
# shellcheck source=../ci_tools.lib.sh
. ../ci_tools.lib.sh
set +a
# set -x

pVersion="@$(git rev-parse --short HEAD)"
pdPod="${RELEASE}-pingdirectory-0"

echo "Creating output folder..."
mkdir -p "${pVersion}"
export pVersion



echo "Generating pd.profile..."

## profile command
kubectl exec -it "${pdPod}" -- manage-profile generate-profile --profileRoot /tmp/pd.profile

## optionally include users
if test ${_includeLdif} ; then
  kubectl exec -it "${pdPod}" -- export-ldif --backendID userRoot --ldifFile /tmp/pd.profile/ldif/userRoot/10-users.ldif --doNotEncrypt
fi

## copy out created profile
kubectl cp "${pdPod}":/tmp/pd.profile "${pVersion}/pd.profile"
rm "${pVersion}/pd.profile/setup-arguments.txt"
rm "${pVersion}/pd.profile/server-root/pre-setup/PingDirectory.lic"

## delete profile from pod. 
kubectl exec -it "${pdPod}" -- rm -rf /tmp/pd.profile


## variablize the profiles based on global vars
getGlobalVars | awk '{ print length($0) " " $0; }' | sort -r -n | cut -d ' ' -f 2- > tmpHosts
./variablize.sh -p "${pVersion}/pd.profile" -e tmpHosts ${_backup}
touch "${pVersion}/env_vars"
echo "#### GLOBAL ENV VARS #####" >> "${pVersion}/env_vars"
cat tmpHosts >> "${pVersion}/env_vars"
rm tmpHosts
if test -f hosts ; then
  ./variablize.sh -p "${pVersion}/pd.profile" -e hosts ${_backup}
  echo "#### HOSTS FILE VARS #####" >> "${pVersion}/env_vars"
  cat hosts >> "${pVersion}/env_vars"
fi

mv "${pVersion}/env_vars" "${pVersion}/tmp_env_vars"
sed 's/=.*$/=/' "${pVersion}/tmp_env_vars" > "${pVersion}/env_vars"
cp -f "${pVersion}/env_vars" "vars_diff"

cd "${_initialDir}" || exit
cp -a "${_scriptDir}/${pVersion}/pd.profile" "profiles/pingdirectory/."
test ! $_backup && rm -rf "${_scriptDir}/${pVersion}/"