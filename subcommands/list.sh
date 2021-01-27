# Command for listing resources
function list-description {
  echo "List ClusterPools, ClusterClaims, and ClusterDeployments"
}

function list-usage {
  errEcho "usage: $(basename ${0}) list pools|claims|clusters"
  errEcho
  errEcho "    $(list-description)"
  errEcho "    Each resource type supports a number of aliases (singular and plural)"
  errEcho "    and is case-insensitve"
  errEcho
  errEcho "    pools (cp, ClusterPool)"
  errEcho "    claims (cc, ClusterClaim)"
  errEcho "    clusters (cd, ClusterDeployment)"
  errEcho
  abort
}

function list {
  case $(echo "$1" | tr '[:upper:]' '[:lower:]') in
    pool*|cp*|clusterpool*)
      ocWithCMContext get ClusterPools
      ;;
    claim*|cc*|clusterclaim*)
      ocWithCMContext get ClusterClaims -o custom-columns="$CLUSTERCLAIM_CUSTOM_COLUMNS"
      ;;
    cluster*|cd*|clusterdeployment*)
      ocWithCMContext get ClusterDeployments -A -L hibernate
      ;;
    *)
      list-usage
      ;;
  esac
}