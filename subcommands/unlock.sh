# Command for unlocking a cluster
function lock_description {
  echo "Unlock a cluster"
}

function hibernate_usage {
  errEcho "usage: $(basename ${0}) unlock [OPTIONS] [CONTEXT]"
  errEcho
  errEcho "    $(unlock_description)"
  errEcho "    Removes a lock from a cluster"
  errEcho "    If you remove the last lock, you may wish to hibernate the cluster"
  errEcho
  errEcho "    CONTEXT is the name of a kube context that matches a ClusterClaim"
  errEcho
  errEcho "    The following OPTIONS are available:"
  errEcho
  errEcho "    -a    Remove all locks"
  errEcho "    -i    Use the provided lock ID instead of username"
  errEcho
  abort
}

function unlock {
  OPTIND=1
  while getopts :ai: o 
  do case "$o" in
    a)  ALL_LOCKS="true";;
    i)  LOCK_ID="$OPTARG";;
    [?]) unlock_usage;;
    esac
  done
  shift $(($OPTIND - 1))
  

  local context=$1
  if [[ -z $context ]]
  then
    context=$(current)
  fi
  case $context in
    cm)
      fatal "Cannot unlock ClusterPool host"
      ;;
    *)
      removeLock "$context" "$LOCK_ID" "$ALL_LOCKS"
      ;;
  esac
}