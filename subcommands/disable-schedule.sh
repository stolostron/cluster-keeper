# Command for disabling hibernation on a cluster
function disable_schedule_description {
  echo "Disable scheduled hibernation/resumption for current or given cluster"
}

function disable_schedule_usage {
  errEcho "usage: $(basename ${0}) disable-schedule [OPTIONS] [CONTEXT]"
  errEcho
  errEcho "    $(disable_schedule_description)"
  errEcho
  errEcho "    CONTEXT is the name of a kubeconfig context that matches a ClusterClaim"
  errEcho
  errEcho "    The following OPTIONS are available:"
  errEcho
  errEcho "    -f    Force operation if cluster is currently locked"
  errEcho
  abort
}

function disable_schedule {
  OPTIND=1
  while getopts :f o 
  do case "$o" in
    f)  export FORCE="true";;
    [?]) disable_schedule_usage;;
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
      disableSchedule $context
      ;;
  esac; 
}