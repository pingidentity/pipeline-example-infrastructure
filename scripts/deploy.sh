#!/usr/bin/env sh
CWD=$(dirname "$0")
. "${CWD}/lib.sh"

echo "${GITHUB_REF}"

## Friendly script info
usage ()
{
cat <<END_USAGE
Usage:  {options} 
    * - required
    where {options} include:
    --verbose|-v
        Use verbose output
    --dry-run|-d
        Show deployment yamls without appying
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
    --dry-run|-d)
      export _dryRun="--dry-run" ;;
    --verbose|-v)
      set -x ;;
    -h|--help)
      exit_usage "./scripts/deploy.sh --dry-run";;
    *)
      exit_usage "Unrecognized Option ${1}" ;;
  esac
  shift
done

## builds sha for each product based on the folder name in ./profiles/* (e.g. pingfederateSha)
  ## this determines what will be redeployed. 
for D in ./profiles/* ; do 
  if [ -d "${D}" ]; then 
    _prodName=$(basename "${D}" | sed 's/-//')
    dirr="${D}"
    eval "${_prodName}Sha=x$(git log -n 1 --pretty=format:%h -- "$dirr")"
  fi
done

## Turn .subst files to hardcoded
expandFiles "helm"

## Finish by cleaning up hardcoded files if not a dry-run
test -z "${_dryRun}" && cleanExpandedFiles