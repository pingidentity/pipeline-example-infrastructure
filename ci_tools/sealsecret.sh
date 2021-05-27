#!/usr/bin/env sh

test -z "${REF}" && REF=$(git rev-parse --abbrev-ref HEAD)
set -a
set -e
# shellcheck source=@localSecrets
test -f ./ci_tools/@localSecrets && . ./ci_tools/@localSecrets

set -x
_initialDir="${PWD}"
_scriptDir="${PWD}/ci_tools"
# cd "${_scriptDir}" || exit

usage ()
{
cat <<END_USAGE
Usage:  {options} 
    * - required
    where {options} include:
    -n*
        namespace for secret
    -f*
        file to encrypt
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
      inputFileClean="$(basename inputFile | sed s/@//)" ;;
    -n)
      shift
      k8sNamespace="${1}" ;;
    -s)
      shift
      secretName="${1}";;
    -h|--help)
      exit_usage "./sealsecret.sh -n cicd-dev -f full/path/to/Pingdirectory.lic -s pingdirectory-license
                   ";;
    *)
      exit_usage "Unrecognized Option" ;;
  esac
  shift
done

if test -z "${inputFile}" || test -z "${secretName}" || test -z "${k8sNamespace}"; then
  exit_usage
fi

test ! -d tmp && mkdir tmp
kubectl create secret generic "${secretName}" --dry-run=client --from-file="${inputFile}" -n  "${k8sNamespace}" -o json > tmp/mysecret.json

test ! -d "k8s/secrets/${k8sNamespace}" && mkdir "k8s/secrets/${k8sNamespace}"
kubeseal <tmp/mysecret.json >"k8s/secrets/${k8sNamespace}/${secretName}".json

rm -rf tmp