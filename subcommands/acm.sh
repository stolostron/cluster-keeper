# Command for launching the ACM console
function acm_description {
  echo "Launch the ACM console for current or given context"
}

function acm_usage {
  errEcho "usage: $(basename ${0}) acm [CONTEXT]"
  errEcho
  errEcho "    $(acm_description)"
  errEcho "    If the context matches a ClusterClaim, the kubeadmin password is copied to the clipboard"
  errEcho
  errEcho "    CONTEXT is the name of a kubeconfig context"
  errEcho "        'cm' context refers to the ClusterPool host"
  errEcho
  errEcho "    The following OPTIONS are available:"
  errEcho
  errEcho "    -f    Force operation if cluster is currently locked"
  errEcho
  abort
}

function acm {
  OPTIND=1
  while getopts :fr o 
  do case "$o" in
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
  verifyContext $context
  if [[ -n $(getClusterClaim "$context") ]]
  then
    copyPW "$context"
  fi
  local acm_url
  acm_url=https://$(sub oc --context $context -n open-cluster-management get route multicloud-console -o jsonpath='{.spec.host}')
  verbose 0 "Opening $acm_url"
  sleep 1
  open $acm_url
}