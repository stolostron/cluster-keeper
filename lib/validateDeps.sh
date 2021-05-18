#!/usr/bin/env bash
# Copyright Contributors to the Open Cluster Management project

# Validate bash version is 4 or greater
if [ "${BASH_VERSINFO:-0}" -lt 4 ]
then
  echo "DEPENDENCY NOT MET. bash version 4 or greater is required to run this tool. Found version ${BASH_VERSION}"
  echo "On MacOS install with \"brew install bash\".  This bash must be first in your path, but need not be '/bin/bash' or your default login shell."
  exit 1
fi

OS=$(uname -s | tr '[:upper:]' '[:lower:]')

# Validate jq is installed
if [ "${OS}" == "darwin" ]; then
    if [ ! -x "$(command -v jq)"  ]; then
       echo "ERROR: jq required, but not found."
       echo "Perform \"brew install jq\" and try again."
       exit 1
    fi
fi


# Validate gsed is installed
if [ "${OS}" == "darwin" ]; then
    SED="gsed"
    if [ ! -x "$(command -v ${SED})"  ]; then
       echo "ERROR: $SED required, but not found."
       echo "Perform \"brew install gnu-sed\" and try again."
       exit 1
    fi
fi