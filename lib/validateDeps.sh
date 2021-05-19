# Copyright Contributors to the Open Cluster Management project

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
function macHint {
  local package=$1
  local extra=$2
  if [ "${OS}" == "darwin" ]; then
    verbose 0 "Install with \"brew install ${package}\" and try again. ${extra}"
  fi
}


# Validate configuration file is present and load
[[ -f $DIR/user.env ]] || fatal "user.env file not found"
. $DIR/user.env

# Validate bash version is 4 or greater
if [ "${BASH_VERSINFO:-0}" -lt 4 ]
then
  error "bash version 4 or greater is required to run this tool. Found version ${BASH_VERSION}"
  macHint bash "This bash must be first in your path but need not be '/bin/bash' or your default login shell."
  abort
fi

# Validate jq is installed
if [ ! -x "$(command -v jq)"  ]; then
    error "jq is required but not found."
    macHint jq
    abort
fi

# Validate sed/gsed is installed
SED=sed
if [ "${OS}" == "darwin" ]; then
  SED=gsed
fi
if [ ! -x "$(command -v $SED)"  ]; then
    error "$SED is required but not found."
    macHint gnu-sed
    abort
fi
