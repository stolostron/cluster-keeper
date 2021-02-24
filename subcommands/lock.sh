# Copyright Contributors to the Open Cluster Management project
# Command for locking a cluster
function lock_description {
  echo "Lock a cluster"
}

function lock_usage {
  errEcho "usage: $(basename ${0}) lock [OPTIONS] [CONTEXT]"
  errEcho
  errEcho "    $(lock_description)"
  errEcho "    A locked cluster will not be hibernated/resumed on schedule"
  errEcho "    Other users are prevented from running certain subcommands on locked"
  errEcho "    clusters, like 'ck run', 'ck hibernate', and 'ck delete'"
  errEcho
  errEcho "    CONTEXT is the name of a kubeconfig context that matches a ClusterClaim"
  errEcho
  errEcho "    The following OPTIONS are available:"
  errEcho
  errEcho "    -i    Use the provided lock ID instead of username"
  errEcho
  abort
}

function lock {
  OPTIND=1
  while getopts :i: o 
  do case "$o" in
    i)  LOCK_ID="$OPTARG";;
    [?]) lock_usage;;
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
      fatal "Cannot lock ClusterPool host"
      ;;
    *)
      addLock "$context" "$LOCK_ID"
      ;;
  esac
}