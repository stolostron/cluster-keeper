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
  errEcho "    CONTEXT is the name of a kube context"
  errEcho "        'cm' context refers to the ClusterPool host"
  errEcho
  abort
}

function console {
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
      if [[ -n $(getClusterClaim "$context") ]]
      then
        copyPW "$context"
      fi
      console_url=https://$(sub oc --context $context -n openshift-console get route console -o jsonpath='{.spec.host}')
      ;;
  esac
  verbose 0 "Opening $console_url"
  sleep 1
  open $console_url
}