# Command for resuming a cluster from hibernation
function run-description {
  echo "Resume a hibernating cluster"
}

function run-usage {
  errEcho "usage: $(basename ${0}) run [CONTEXT]"
  errEcho
  errEcho "    $(run-description)"
  errEcho
  errEcho "    CONTEXT is the name of a kube context that matches a ClusterClaim"
  errEcho
  errEcho "    The following OPTIONS are available:"
  errEcho
  errEcho "    -f    Force operation if cluster is currently held"
  errEcho
  abort
}

function run {
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
      fatal "Cannot resume ClusterPool host"
      ;;
    *)
      setPowerState $context "Running" $FORCE
      ;;
  esac
}