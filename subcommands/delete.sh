# Command for deleting a ClusterClaims
function delete_description {
  echo "Delete a cluster by deleting its ClusterClaim"
}

function delete_usage {
  errEcho "usage: $(basename ${0}) delete [OPTIONS] [CONTEXT]"
  errEcho
  errEcho "    $(delete_description)"
  errEcho
  errEcho "    CONTEXT is the name of a kubeconfig context that matches a ClusterClaim"
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

  local context=$1
  if [[ -z $context ]]
  then
    context=$(current)
  fi

  # if [[ -z $1 ]]
  # then
  #   delete_usage
  # fi


  local clusterDeployment=$(getClusterDeployment $context)
  if [[ -n $clusterDeployment ]]
  then
    checkLocks $context
  fi

  # Use lifeguard/clusterclaims/delete.sh to delete ClusterClaim
  export CLUSTERCLAIM_NAME=$context
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