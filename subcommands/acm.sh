# Command for launching the ACM console
function acm-description {
  echo "Launch the ACM console for current or given context"
}

function acm-usage {
  errEcho "usage: $(basename ${0}) acm [CONTEXT]"
  errEcho
  errEcho "    $(acm-description)"
  errEcho "    If the context matches a ClusterClaim, the kubeadmin password is copied to the clipboard"
  errEcho
  errEcho "    CONTEXT is the name of a kube context"
  errEcho "        'cm' context refers to the ClusterPool host"
  errEcho
  abort
}

function acm {
  local context=$1
  if [[ -z $context ]]
  then
    context=$(current)
  fi
  local acm_url
  acm_url=https://$(sub oc --context $context -n open-cluster-management get route multicloud-console -o jsonpath='{.spec.host}')
  verbose 0 "Opening $acm_url"
  open $acm_url
}