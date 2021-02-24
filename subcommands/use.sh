# Command for switching contexts
function use_description {
  echo "Switch kubeconfig context"
}

function use_usage {
  errEcho "usage: $(basename ${0}) use CONTEXT"
  errEcho
  errEcho "    $(use_description)"
  errEcho "    If the context matches a ClusterClaim and the cluster is currently"
  errEcho "    hibernating, it is resumed"
  errEcho
  errEcho "    CONTEXT is the name of a kubeconfig context"
  errEcho "        '$CLUSTERPOOL_CONTEXT_NAME' context refers to the ClusterPool host"
  errEcho
  errEcho "    -f    Force operation if cluster is currently locked"
  errEcho
  abort
}

function use {
  OPTIND=1
  while getopts :f o 
  do case "$o" in
    f)  export FORCE="true";;
    [?]) use_usage;;
    esac
  done
  shift $(($OPTIND - 1))

  if [[ -z $1 ]]
  then
    use_usage
  fi
  case $1 in
    $CLUSTERPOOL_CONTEXT_NAME)
      ocWithContext $CLUSTERPOOL_CONTEXT_NAME config use-context $CLUSTERPOOL_CONTEXT_NAME
      ;;
    *)
      ocWithContext "$1" config use-context "$1"
      ;;
  esac;
}