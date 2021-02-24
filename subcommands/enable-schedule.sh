# Command for enabling hibernation on a cluster
function enable_schedule_description {
  echo "Enable scheduled hibernation/resumption for current or given cluster"
}

function enable_schedule_usage {
  errEcho "usage: $(basename ${0}) enable-schedule [OPTIONS] [CONTEXT]"
  errEcho
  errEcho "    $(enable_schedule_description)"
  errEcho
  errEcho "    CONTEXT is the name of a kubeconfig context that matches a ClusterClaim"
  errEcho
  errEcho "    The following OPTIONS are available:"
  errEcho
  errEcho "    -f    Force operation if cluster is currently locked"
  errEcho
  abort
}

function enable_schedule {
  OPTIND=1
  while getopts :f o 
  do case "$o" in
    f)  export FORCE="true";;
    [?]) enable_schedule_usage;;
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
      fatal "Cannot control hibernation for the ClusterPool host"
      ;;
    *)
      enableSchedule $context
      ;;
  esac; 
}