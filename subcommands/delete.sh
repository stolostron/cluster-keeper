# Command for deleting a ClusterClaims
function delete_description {
  echo "Delete a cluster by deleting its ClusterClaim"
}

function delete_usage {
  errEcho "usage: $(basename ${0}) delete [OPTIONS] CLAIM"
  errEcho
  errEcho "    $(delete_description)"
  errEcho
  errEcho "    CLAIM is the name for the new ClusterClaim"
  errEcho
  errEcho "    The following OPTIONS are available:"
  errEcho
  errEcho "    -f    Force operation if cluster is currently locked"
  errEcho "    -y    Delete without confirmation"
  errEcho
  abort
}

function delete {

  OPTIND=1
  while getopts :fy o 
  do case "$o" in
    f)  export FORCE="true";;
    y)  CONFIRM_DELETION="true";;
    [?]) delete_usage;;
    esac
  done
  shift $(($OPTIND - 1))

  if [[ -z $1 ]]
  then
    delete_usage
  fi


  local clusterDeployment=$(getClusterDeployment $1)
  if [[ -n $clusterDeployment ]]
  then
    checkLocks $1
  fi

  # Use lifeguard/clusterclaims/delete.sh to delete ClusterClaim
  export CLUSTERCLAIM_NAME=$1
  export CLUSTERPOOL_TARGET_NAMESPACE
  if [[ -z "$CONFIRM_DELETION" ]]
  then
    withContext cm dirSensitiveCmd $(dependency lifeguard/clusterclaims/delete.sh)
  else
    withContext cm dirSensitiveCmd $(dependency lifeguard/clusterclaims/delete.sh) << EOF
Y
EOF
  fi
}