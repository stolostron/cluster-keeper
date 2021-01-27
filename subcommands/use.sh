# Command for switching contexts
function use-description {
  echo "Switch kube context"
}

function use-usage {
  errEcho "usage: $(basename ${0}) use CONTEXT"
  errEcho
  errEcho "    $(use-description)"
  errEcho "    If the context matches a ClusterClaim and the cluster is currently"
  errEcho "    hibernating, it is resumed"
  errEcho
  errEcho "    CONTEXT is the name of a kube context"
  errEcho "        'cm' context refers to the ClusterPool host"
  errEcho
  abort
}

function use {
  if [[ -z $1 ]]
  then
    use-usage
  fi
  case $1 in
    cm)
      ocWithCMContext config use-context cm
      ;;
    *)
      notImplemented
      ;;
  esac;
}