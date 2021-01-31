# Command for running scripts with a given context
function with_description {
  echo "Run any command with the given context"
}

function with_usage {
  errEcho "usage: $(basename ${0}) with CONTEXT COMMAND"
  errEcho
  errEcho "    $(with_description)"
  errEcho "    If the context matches a ClusterClaim and the cluster is currently"
  errEcho "    hibernating, it is resumed"
  errEcho
  errEcho "    CONTEXT is the name of a kube context"
  errEcho "        'cm' context refers to the ClusterPool host"
  errEcho "    COMMAND is any command, such as a script that invokes oc or kubectl"
  errEcho
  errEcho "    -f    Force operation if cluster is currently locked"
  errEcho
  abort
}

function with {
  OPTIND=1
  while getopts :f o 
  do case "$o" in
    f)  export FORCE="true";;
    [?]) with_usage;;
    esac
  done
  shift $(($OPTIND - 1))

  if [[ -z $1 || -z $2 ]]
  then
    with_usage
  fi

  local context=$1
  shift

  withContext "$context" "$@"
}