# Command for viewing current kube context
function current_description {
  echo "Display the current kube context"
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