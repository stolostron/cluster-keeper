# Copyright Contributors to the Open Cluster Management project
# Command for displaying location of kubeconfig file
function kubeconfig_description {
  echo "Display the location of the kubeconfig file"
}

function kubeconfig_usage {
  errEcho "usage: $(basename ${0}) kubeconfig [OPTIONS] [CONTEXT]"
  errEcho
  errEcho "    $(kubeconfig_description)"
  errEcho
  errEcho "    CONTEXT is the name of a kubeconfig context that matches a ClusterClaim"
  errEcho
  errEcho "    The following OPTIONS are available:"
  errEcho
  errEcho "    -r    Refresh the kubeconfig by fetching a fresh copy"
  errEcho
  abort
}

function kubeconfig {
  OPTIND=1
  while getopts :r o 
  do case "$o" in
    r)  FETCH_FRESH="true";;
    [?]) creds_usage;;
    esac
  done
  shift $(($OPTIND - 1))

  local context=$1
  if [[ -z $context ]]
  then
    context=$(current)
  fi
  case $context in
    $CLUSTERPOOL_CONTEXT_NAME)
      fatal "Cannot show kubeconfig file location for the ClusterPool host"
      ;;
    *)
      showKubeconfig $context $FETCH_FRESH
      ;;
  esac
}