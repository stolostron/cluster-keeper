# Command for hibernating a cluster
function hibernate-description {
  echo "Hibernate a cluster"
}

function run-usage {
  errEcho "usage: $(basename ${0}) hibernate [CONTEXT]"
  errEcho
  errEcho "    $(hibernate-description)"
  errEcho
  errEcho "    CONTEXT is the name of a kube context that matches a ClusterClaim"
  errEcho
  errEcho "    The following OPTIONS are available:"
  errEcho
  errEcho "    -f    Force operation if cluster is currently held"
  errEcho
  abort
}

function hibernate {
  OPTIND=1
  while getopts :f o 
  do case "$o" in
    f)  FORCE="true";;
    [?]) usage;;
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
      fatal "Cannot hibernate ClusterPool host"
      ;;
    *)
      setPowerState $context "Hibernating" $FORCE
      ;;
  esac
}