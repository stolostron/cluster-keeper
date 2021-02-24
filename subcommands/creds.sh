# Copyright Contributors to the Open Cluster Management project
# Command for displaying credentials and other information
function creds_description {
  echo "Display credentials for a cluster"
}

function creds_usage {
  errEcho "usage: $(basename ${0}) creds [OPTIONS] [CONTEXT]"
  errEcho
  errEcho "    $(creds_description)"
  errEcho "    CAUTION: This will display the admin password."
  errEcho
  errEcho "    CONTEXT is the name of a kubeconfig context that matches a ClusterClaim"
  errEcho
  errEcho "    The following OPTIONS are available:"
  errEcho
  errEcho "    -f    Force operation if cluster is currently locked"
  errEcho "    -p    Extract a single property, like password or api_url"
  errEcho "    -r    Refresh the credentials by fetching a fresh copy"
  errEcho
  abort
}

function creds {
  OPTIND=1
  while getopts :fp:r o 
  do case "$o" in
    f)  export FORCE="true";;
    p)  PROPERTY="$OPTARG";;
    r)  FETCH_FRESH="true";;
    [?]) creds_usage;;
    esac
  done
  shift $(($OPTIND - 1))

  local context=$1
  if [[ -z $context ]]
  then
    context=$(current)
  fi
  case $context in
    $CLUSTERPOOL_CONTEXT_NAME)
      fatal "Cannot display credentials for the ClusterPool host"
      ;;
    *)
      if [[ -z $PROPERTY ]]
      then
        displayCreds $context $FETCH_FRESH
      else
        displayCreds $context $FETCH_FRESH | jq -r ".$PROPERTY"
      fi
      ;;
  esac
}