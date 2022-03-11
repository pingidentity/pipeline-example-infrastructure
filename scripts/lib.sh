#!/usr/bin/env sh

RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# prep for expandFiles
getEnvKeys() {
    env | cut -d'=' -f1 | sed -e 's/^/$/'
}

# process all files that end in .subst
expandFiles() {
    echo $*
    _expandPath="${1}"
    echo "  Processing templates"

    find "${_expandPath}" -type f -iname "*.subst" > tmpFileList
    while IFS= read -r template; do
        echo "    t - ${template}"
        _templateDir="$(dirname ${template})"
        _templateBase="$(basename ${template})"
        envsubst "'$(getEnvKeys)'" < "${template}" > "${_templateDir}/${_templateBase%.subst}"
        echo "${_templateDir}/${_templateBase#subst.}" >> expandedFiles
    done < tmpFileList
    rm tmpFileList
}

# for cleanup on local when not dry-run
cleanExpandedFiles() {
  while IFS= read -r file; do
    rm "${file}"
  done < expandedFiles
}