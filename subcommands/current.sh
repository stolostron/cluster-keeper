# Command for viewing current kube context
function current-description {
  echo "Display the current kube context"
}

function current-usage {
  errEcho "usage: $(basename ${0}) current"
  errEcho
  errEcho "    $(current-description)"
  errEcho
  abort
}

function current {
  oc config current-context
}