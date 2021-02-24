# Command for hibernating a cluster
function hibernate_description {
  echo "Hibernate a cluster"
}

function hibernate_usage {
  errEcho "usage: $(basename ${0}) hibernate [CONTEXT]"
  errEcho
  errEcho "    $(hibernate_description)"
  errEcho
  errEcho "    CONTEXT is the name of a kubeconfig context that matches a ClusterClaim"
  errEcho
  errEcho "    The following OPTIONS are available:"
  errEcho
  errEcho "    -f    Force operation if cluster is currently locked"
  errEcho
  abort
}

function hibernate {
  OPTIND=1
  while getopts :f o 
  do case "$o" in
    f)  export FORCE="true";;
    [?]) hibernate_usage;;
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
      fatal "Cannot hibernate ClusterPool host"
      ;;
    *)
      setPowerState $context "Hibernating"
      ;;
  esac
}