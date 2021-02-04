# Command for copying cluster password to clipboard
function pw_description {
  echo "Copy a cluster password to the clipboard"
}

function pw_usage {
  errEcho "usage: $(basename ${0}) pw [OPTIONS] [CONTEXT]"
  errEcho
  errEcho "    $(pw_description)"
  errEcho "    CAUTION: This will display the admin password."
  errEcho
  errEcho "    CONTEXT is the name of a kubeconfig context that matches a ClusterClaim"
  errEcho
  errEcho "    The following OPTIONS are available:"
  errEcho
  errEcho "    -r    Refresh the credentials by fetching a fresh copy"
  errEcho
  abort
}

function pw {
  OPTIND=1
  while getopts :r o 
  do case "$o" in
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
    cm)
      fatal "Cannot copy password for the ClusterPool host"
      ;;
    *)
      copyPW $context $FETCH_FRESH
      ;;
  esac
}