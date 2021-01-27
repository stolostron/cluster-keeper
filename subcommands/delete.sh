# Command for deleting a ClusterClaims
function delete-description {
  echo "Delete a cluster by deleting its ClusterClaim"
}

function delete-usage {
  errEcho "usage: $(basename ${0}) delete [OPTIONS] CLAIM"
  errEcho
  errEcho "    $(delete-description)"
  errEcho
  errEcho "    CLAIM is the name for the new ClusterClaim"
  errEcho
  errEcho "    The following OPTIONS are available:"
  errEcho
  errEcho "    -f    Force operation if cluster is currently held"
  errEcho "    -y    Delete without confirmation"
  errEcho
  abort
}

function delete {

  OPTIND=1
  while getopts :fy o 
  do case "$o" in
    f)  FORCE="true";;
    y)  FORCE_DELETION="true";;
    [?]) usage;;
    esac
  done
  shift $(($OPTIND - 1))

  if [[ -z $1 ]]
  then
    delete-usage
  fi

  if [[ -z $FORCE ]]
  then
    local clusterDeployment=$(getClusterDeployment $1)
    if [[ -n $clusterDeployment ]]
    then
      checkHolds $1
    fi
  fi

  # Use lifeguard/clusterclaims/delete.sh to delete ClusterClaim
  export CLUSTERCLAIM_NAME=$1
  export CLUSTERPOOL_TARGET_NAMESPACE
  if [[ -z "$FORCE_DELETION" ]]
  then
    withCMContext dirSensitiveCmd $(dependency lifeguard/clusterclaims/delete.sh)
  else
    withCMContext dirSensitiveCmd $(dependency lifeguard/clusterclaims/delete.sh) << EOF
Y
EOF
  fi
}