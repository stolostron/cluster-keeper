#!/usr/bin/env bash
# Copyright Contributors to the Open Cluster Management project

if [ "${BASH_VERSINFO:-0}" < 4 ]
then
  echo "DEPENDENCY NOT MET. bash version 4 or greater is required to run this tool. Found version ${BASH_VERSION}"
  echo "On MacOS install with 'brew install bash'.  This bash must be first in your path, but need not be `/bin/bash` or your default login shell."
  exit 1
fi