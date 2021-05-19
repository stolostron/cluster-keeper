#!/usr/bin/env bash
# Copyright Contributors to the Open Cluster Management project

function abort {
  kill -s TERM $TOP_PID
}

function errEcho {
  echo >&2 "$@"
}

function verbose {
  local verbosity=$1
  shift
  if [[ $verbosity -le $VERBOSITY ]]
  then
    errEcho "$@"
  fi
}

function logCommand {
  verbose $COMMAND_VERBOSITY "command: $@"
}

function logOutput {
  verbose $OUTPUT_VERBOSITY "output:"
  verbose $OUTPUT_VERBOSITY "$@"
}

function error {
  echo >&2 "error: $@"
}

function fatal {
  error "$@"
  abort
}

# Use to silence output when not using "return" value from a function
function ignoreOutput {
  "$@" > /dev/null
}