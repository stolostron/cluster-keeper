# Command for creating new ClusterClaims
function new-description {
  echo "Get a new cluster by creating a ClusterClaim"
}

function new-usage {
  errEcho "usage: $(basename ${0}) new [OPTIONS] POOL CLAIM"
  errEcho
  errEcho "    $(new-description)"
  errEcho
  errEcho "    POOL is the name of the ClusterPool"
  errEcho "    CLAIM is the name for the new ClusterClaim"
  errEcho
  errEcho "    The following OPTIONS are available:"
  errEcho
  errEcho "    -l    Lifetime of the cluster in hours"
  errEcho "    -m    Manual power management; do not configure for hibernation"
  errEcho
  abort
}

function new {

  OPTIND=1
  while getopts :l:m o 
  do case "$o" in
    l)  CLUSTERCLAIM_LIFETIME="${OPTARG}h";;
    m)  MANUAL_POWER="true";;
    [?]) usage;;
    esac
  done
  shift $(($OPTIND - 1))

  if [[ -z $1 || -z $2 ]]
  then
    new-usage
  fi

  # Use lifeguard/clusterclaims/apply.sh to create ClusterClaim
  export CLUSTERPOOL_NAME=$1
  export CLUSTERCLAIM_NAME=$2
  export CLUSTERPOOL_TARGET_NAMESPACE
  export CLUSTERCLAIM_GROUP_NAME
  export CLUSTERCLAIM_LIFETIME
  export SKIP_WAIT_AND_CREDENTIALS="true"
  withCMContext dirSensitiveCmd $(dependency lifeguard/clusterclaims/apply.sh) << EOF
N
EOF
  
  enableServiceAccounts $2
  if [[ -z $MANUAL_POWER && $AUTO_HIBERNATION = "true" ]]
  then
    enableSchedule $2
  else
    disableSchedule $2
  fi

  getCreds $2

}