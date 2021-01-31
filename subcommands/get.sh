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
  errEcho "        if omitted, the current kube context is used if it matches a ClusterClaim"
  errEcho "    ARGS are additional args passed through to 'oc get' such as '-o yaml'"
  errEcho
  abort
}

function get {
  local type=$1
  local name=$2
  local claim
  
  if [[ -z $name ]]
  then
    claim=$(getClusterClaim $(current) "required")
  fi
  shift
  
  case $(echo "$type" | tr '[:upper:]' '[:lower:]') in
    pool*|cp*|clusterpool*)
      if [[ -n $claim ]]
      then
        ocWithContext cm get ClusterPool $(getClusterPool $(current) "required")
      else
        if [[ $(subRC oc --context cm get ClusterPool $name) -eq 0 ]]
        then
          shift
          ocWithContext cm get ClusterPool $name "$@"
        elif [[ -n $(getClusterClaim $name) ]]
        then
          shift
          ocWithContext cm get ClusterPool $(getClusterPool $name "required") "$@"
        else
          ocWithContext cm get ClusterPool $(getClusterPool $(current) "required") "$@"
        fi
      fi
      ;;
    claim*|cc*|clusterclaim*)
      if [[ -n $claim ]]
      then
        ocWithContext cm get ClusterClaim $claim -o custom-columns="$CLUSTERCLAIM_CUSTOM_COLUMNS"
      else
        local clusterClaim=$(getClusterClaim $name)
        if [[ -n $clusterClaim ]]
        then
          shift
          ocWithContext cm get ClusterClaim $clusterClaim -o custom-columns="$CLUSTERCLAIM_CUSTOM_COLUMNS" "$@"
        else
          ocWithContext cm get ClusterClaim $(getClusterClaim $(current) "required") -o custom-columns="$CLUSTERCLAIM_CUSTOM_COLUMNS" "$@"
        fi
      fi
      ;;
    cluster*|cd*|clusterdeployment*)
      if [[ -n $claim ]]
      then
        local clusterDeployment=$(getClusterDeployment $(current) "required")
        ocWithContext cm -n $clusterDeployment get ClusterDeployment $clusterDeployment -L hibernate
      else
        if [[ $(subRC oc --context cm -n $name get ClusterDeployment $name) -eq 0 ]]
        then
          shift
          ocWithContext cm -n $name get ClusterDeployment $name -L hibernate "$@"
        elif [[ -n $(getClusterClaim $name) ]]
        then
          shift
          local clusterDeployment=$(getClusterDeployment $name "required")
          ocWithContext cm -n $clusterDeployment get ClusterDeployment $clusterDeployment -L hibernate "$@"
        else
          local clusterDeployment=$(getClusterDeployment $(current) "required")
          ocWithContext cm -n $clusterDeployment get ClusterDeployment $clusterDeployment "$@"
        fi
      fi
      ;;
    *)
      get_usage
      ;;
  esac
}