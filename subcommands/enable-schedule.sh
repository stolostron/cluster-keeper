# Command for enabling hibernation on a cluster
function enable-schedule-description {
  echo "Enable scheduled hibernation/resumption for current or given cluster"
}

function enable-schedule-usage {
  errEcho "usage: $(basename ${0}) enable-schedule [OPTIONS] [CONTEXT]"
  errEcho
  errEcho "    $(enable-schedule-description)"
  errEcho
  errEcho "    CONTEXT is the name of a kube context that matches a ClusterClaim"
  errEcho
  errEcho "    The following OPTIONS are available:"
  errEcho
  errEcho "    -f    Force operation if cluster is currently held"
  errEcho
  abort
}

function enable-schedule {
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
      fatal "Cannot control hibernation for the ClusterPool host"
      ;;
    *)
      enableSchedule $context $FORCE
      ;;
  esac; 
}