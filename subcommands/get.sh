# Copyright Contributors to the Open Cluster Management project
# Command for getting resources
function get_description {
  echo "Get a ClusterPool, ClusterClaim, or ClusterDeployment"
}

function get_usage {
  errEcho "usage: $(basename ${0}) get pool|claim|cluster [NAME] [ARGS]"
  errEcho
  errEcho "    $(get_description)"
  errEcho "    Each resource type supports a number of aliases (singular and plural)"
  errEcho "    and is case-insensitve"
  errEcho
  errEcho "    pool (cp, ClusterPool)"
  errEcho "    claim (cc, ClusterClaim)"
  errEcho "    cluster (cd, ClusterDeployment)"
  errEcho
  errEcho "    NAME is the name of the resource or the related ClusterClaim"
  errEcho "        if omitted, the current kubeconfig context is used if it matches a ClusterClaim"
  errEcho "    ARGS are additional args passed through to 'oc get' such as '-o yaml'"
  errEcho
  abort
}

function get {
  local type=$1
  local name=$2
  local claim clusterClaim clusterPool clusterDeployment
  
  if [[ -z $name ]]
  then
    claim=$(getClusterClaim $(current) "required")
  fi
  shift
  
  case $(echo "$type" | tr '[:upper:]' '[:lower:]') in
    pool*|cp*|clusterpool*)
      if [[ -n $claim ]]
      then
        ocWithContext $CLUSTERPOOL_CONTEXT_NAME get ClusterPool $(getClusterPool $(current) "required")
      else
        if [[ $(subRC oc --context $CLUSTERPOOL_CONTEXT_NAME get ClusterPool $name) -eq 0 ]]
        then
          shift
          clusterPool=$name
        elif [[ -n $(getClusterClaim $name) ]]
        then
          shift
          clusterPool=$(getClusterPool $name "required")
        else
          clusterPool=$(getClusterPool $(current) "required")
        fi
        ocWithContext $CLUSTERPOOL_CONTEXT_NAME get ClusterPool $clusterPool "$@"
      fi
      ;;
    claim*|cc*|clusterclaim*)
      if [[ -n $claim ]]
      then
        ocWithContext $CLUSTERPOOL_CONTEXT_NAME get ClusterClaim $claim -o custom-columns="$CLUSTERCLAIM_CUSTOM_COLUMNS" | enhanceClusterClaimOutput
      else
        clusterClaim=$(getClusterClaim $name)
        if [[ -z $clusterClaim ]]
        then
          clusterClaim=$(getClusterClaim $(current) "required")
        else
          shift
        fi
        if [[ -z "$@" ]]
        then
          ocWithContext $CLUSTERPOOL_CONTEXT_NAME get ClusterClaim $clusterClaim -o custom-columns="$CLUSTERCLAIM_CUSTOM_COLUMNS" | enhanceClusterClaimOutput
        else  
          ocWithContext $CLUSTERPOOL_CONTEXT_NAME get ClusterClaim $clusterClaim "$@"
        fi
      fi
      ;;
    cluster*|cd*|clusterdeployment*)
      if [[ -n $claim ]]
      then
        local clusterDeployment=$(getClusterDeployment $(current) "required")
        ocWithContext $CLUSTERPOOL_CONTEXT_NAME -n $clusterDeployment get ClusterDeployment $clusterDeployment -L hibernate
      else
        if [[ $(subRC oc --context $CLUSTERPOOL_CONTEXT_NAME -n $name get ClusterDeployment $name) -eq 0 ]]
        then
          shift
          clusterDeployment=$name
        elif [[ -n $(getClusterClaim $name) ]]
        then
          shift
          clusterDeployment=$(getClusterDeployment $name "required")
        else
          clusterDeployment=$(getClusterDeployment $(current) "required")
        fi
        ocWithContext $CLUSTERPOOL_CONTEXT_NAME -n $clusterDeployment get ClusterDeployment $clusterDeployment -L hibernate "$@"
      fi
      ;;
    *)
      get_usage
      ;;
  esac
}