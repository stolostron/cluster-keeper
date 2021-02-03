# Command for creating new ClusterClaims
function new_description {
  echo "Get a new cluster by creating a ClusterClaim"
}

function new_usage {
  errEcho "usage: $(basename ${0}) new [OPTIONS] POOL CLAIM"
  errEcho
  errEcho "    $(new_description)"
  errEcho
  errEcho "    POOL is the name of the ClusterPool"
  errEcho "    CLAIM is the name for the new ClusterClaim"
  errEcho
  errEcho "    The following OPTIONS are available:"
  errEcho
  errEcho "    -l    Lifetime of the cluster in hours"
  errEcho "    -m    Manual power management; do not enable scheduled hibernation"
  errEcho
  abort
}

function new {

  OPTIND=1
  while getopts :l:m o 
  do case "$o" in
    l)  CLUSTERCLAIM_LIFETIME="${OPTARG}h";;
    m)  MANUAL_POWER="true";;
    [?]) new_usage;;
    esac
  done
  shift $(($OPTIND - 1))

  if [[ -z $1 || -z $2 ]]
  then
    new_usage
  fi

  # Use lifeguard/clusterclaims/apply.sh to create ClusterClaim
  export CLUSTERPOOL_NAME=$1
  export CLUSTERCLAIM_NAME=$2
  export CLUSTERPOOL_TARGET_NAMESPACE
  export CLUSTERCLAIM_GROUP_NAME
  export CLUSTERCLAIM_LIFETIME
  export SKIP_WAIT_AND_CREDENTIALS="true"
  withContext cm dirSensitiveCmd $(dependency lifeguard/clusterclaims/apply.sh) << EOF
N
EOF

  enableServiceAccounts $2
  if [[ -z $MANUAL_POWER && $AUTO_HIBERNATION == "true" ]]
  then
    enableSchedule $2
  else
    disableSchedule $2
  fi
}