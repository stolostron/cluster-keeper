# Command for checking the state of a cluster
function state_description {
  echo "Get the power state of a cluster"
}

function state_usage {
  errEcho "usage: $(basename ${0}) state [CONTEXT]"
  errEcho
  errEcho "    $(state_description)"
  errEcho
  errEcho "    CONTEXT is the name of a kube context that matches a ClusterClaim"
  errEcho
  abort
}

function state {
  local context=$1
  if [[ -z $context ]]
  then
    context=$(current)
  fi
  case $context in
    cm)
      fatal "Cannot get power state for the ClusterPool host"
      ;;
    *)
      clusterDeployment=$(getClusterDeployment $1 "required")
      ocWithContext cm -n $clusterDeployment get ClusterDeployment $clusterDeployment -o custom-columns=PowerState:'.status.conditions[?(@.type=="Hibernating")].reason' --no-headers
      ;;
  esac
}