# Command for enabling namespace service accounts on a cluster
function enable_sa_description {
  echo "Enable namespace service accounts for current or given cluster"
}

function enable_sa_usage {
  errEcho "usage: $(basename ${0}) enable-sa [OPTIONS] [CONTEXT]"
  errEcho
  errEcho "    $(enable_sa_description)"
  errEcho "    Run if you do not have permission to edit the ClusterDeployment for a ClusterClaim"
  errEcho
  errEcho "    CONTEXT is the name of a kubeconfig context that matches a ClusterClaim"
  errEcho
  abort
}

function enable_sa {
  local context=$1
  if [[ -z $context ]]
  then
    context=$(current)
  fi
  case $context in
    cm)
      fatal "Cannot enable service accounts for the ClusterPool host"
      ;;
    *)
      enableServiceAccounts $context
      ;;
  esac; 
}