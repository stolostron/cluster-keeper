#!/usr/bin/env bash
# Copyright Contributors to the Open Cluster Management project

source ${DIR}/lib/logging.sh

# Validate bash version is 4 or greater
if [ "${BASH_VERSINFO:-0}" -lt 4 ]
then
  error "DEPENDENCY NOT MET. bash version 4 or greater is required to run this tool. Found version ${BASH_VERSION}"
  verbose 0 "On MacOS install with \"brew install bash\".  This bash must be first in your path, but need not be '/bin/bash' or your default login shell."
  abort
fi

OS=$(uname -s | tr '[:upper:]' '[:lower:]')

# Validate jq is installed
if [ "${OS}" == "darwin" ]; then
    if [ ! -x "$(command -v jq)"  ]; then
       error "jq is required, but not found."
       verbose 0 "On MacOS install with \"brew install jq\" and try again."
       abort
    fi
fi


# Validate gsed is installed
if [ "${OS}" == "darwin" ]; then
    if [ ! -x "$(command -v gsed)"  ]; then
       error "gsed is required, but not found."
       verbose 0 "On MacOS install with \"brew install gnu-sed\" and try again."
       abort
    fi
fi