# Command for running scripts with a given context
function with-description {
  echo "Run any command with the given context"
}

function with-usage {
  errEcho "usage: $(basename ${0}) with CONTEXT COMMAND"
  errEcho
  errEcho "    $(with-description)"
  errEcho "    If the context matches a ClusterClaim and the cluster is currently"
  errEcho "    hibernating, it is resumed"
  errEcho
  errEcho "    CONTEXT is the name of a kube context"
  errEcho "        'cm' context refers to the ClusterPool host"
  errEcho "    COMMAND is any command, such as a script that invokes oc or kubectl"
  errEcho
  abort
}

function with {

  if [[ -z $1 || -z $2 ]]
  then
    with-usage
  fi

  local context=$1
  shift

  case $context in
    cm)
      withCMContext $@
      ;;
    *)
      notImplemented
      ;;
  esac;
}