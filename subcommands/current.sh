# Copyright Contributors to the Open Cluster Management project
# Command for viewing current kubeconfig context
function current_description {
  echo "Display the current kubeconfig context"
}

function current_usage {
  errEcho "usage: $(basename ${0}) current"
  errEcho
  errEcho "    $(current_description)"
  errEcho
  abort
}

function current {
  oc config current-context
}