#!/usr/bin/env sh

test -z "${REF}" && REF=$(git rev-parse --abbrev-ref HEAD)
set -a
set -e
# shellcheck source=@localSecrets
test -f ./ci_tools/@localSecrets && . ./ci_tools/@localSecrets
# shellcheck source=./ci_tools.lib.sh
. ./ci_tools/ci_tools.lib.sh

# set -x
_initialDir="${PWD}"
_scriptDir="${PWD}/ci_tools"
k8sNamespace="${K8S_NAMESPACE}"
# k8sNamespace="${K8S_NAMESPACE}"
# cd "${_scriptDir}" || exit


usage ()
{
cat <<END_USAGE
This script will create a Bitnami SealedSecret file
  The namespace for secret is based on ci_tools vars
Usage:  {options} 
    * - required
    where {options} include:
    -f*
        file to encrypt
    -s
        secret resource name
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
    -f)
      shift
      inputFile="${1}"
      inputFileClean="$(basename $inputFile | sed s/@//)" ;;
    -s)
      shift
      secretName="${1}";;
    -v)
      set -x;;
    -h|--help)
      exit_usage "./sealsecret.sh -n cicd-dev -f full/path/to/Pingdirectory.lic -s pingdirectory-license
                   ";;
    *)
      exit_usage "Unrecognized Option" ;;
  esac
  shift
done

if test -z "${inputFile}"; then
  exit_usage
fi

if test -z "${secretName}"; then
  secretName="${inputFileClean%.*}"
fi

test ! -d tmp && mkdir tmp
kubectl create secret generic "${secretName}" --dry-run=client --from-file="${inputFile}" -n  "${K8S_NAMESPACE}" -o json > tmp/mysecret.json

test ! -d "${K8S_SECRETS_DIR}" && mkdir -p "${K8S_SECRETS_DIR}"
kubeseal < tmp/mysecret.json > "${K8S_SECRETS_DIR}/${secretName}.json"

rm -rf tmp