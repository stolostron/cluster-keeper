# Command for launching the OpenShift console
function console_description {
  echo "Launch the OpenShift console for current or given context"
}

function console_usage {
  errEcho "usage: $(basename ${0}) console [CONTEXT]"
  errEcho
  errEcho "    $(console_description)"
  errEcho "    If the context matches a ClusterClaim, the kubeadmin password is copied to the clipboard"
  errEcho
  errEcho "    CONTEXT is the name of a kubeconfig context"
  errEcho "        'cm' context refers to the ClusterPool host"
  errEcho
  errEcho "    The following OPTIONS are available:"
  errEcho
  errEcho "    -d    Display the console URL only"
  errEcho "    -f    Force operation if cluster is currently locked"
  errEcho
  abort
}

function console {
  OPTIND=1
  while getopts :df o 
  do case "$o" in
    d)  export DISPLAY="true";;
    f)  export FORCE="true";;
    [?]) creds_usage;;
    esac
  done
  shift $(($OPTIND - 1))
  
  local context=$1
  if [[ -z $context ]]
  then
    context=$(current)
  fi
  local console_url
  case $context in
    cm)
      console_url=$CLUSTERPOOL_CONSOLE
      ;;
    *)
      verifyContext "$context"
      if [[ -z $DISPLAY && -n $(getClusterClaim "$context") ]]
      then
        copyPW "$context"
      fi
      console_url=https://$(sub oc --context $context -n openshift-console get route console -o jsonpath='{.spec.host}')
      ;;
  esac
  if [[ -n $DISPLAY ]]
  then
    echo $console_url
  else
    verbose 0 "Opening $console_url"
    sleep 1
    open $console_url
  fi
}