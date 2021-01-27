VERBOSITY=0
AUTO_HIBERNATION=true
COMMAND_VERBOSITY=2
OUTPUT_VERBOSITY=3
CLUSTER_WAIT_MAX=60
HIBERNATE_WAIT_MAX=15

CLUSTERCLAIM_CUSTOM_COLUMNS="\
NAME:.metadata.name,\
POOL:.spec.clusterPoolName,\
CLUSTER:.spec.namespace,\
HOLDS:.metadata.annotations.open-cluster-management\.io/cluster-manager-holds,\
SUBJECTS:.spec.subjects[*].name,\
SCHEDULE:.metadata.annotations.open-cluster-management\.io/cluster-manager-hibernation,\
LIFETIME:.spec.lifetime,\
AGE:.metadata.creationTimestamp"

function abort {
  kill -s TERM $TOP_PID
}

function errEcho {
  echo >&2 "$@"
}

function verbose {
  local verbosity=$1
  shift
  if [[ $verbosity -le $VERBOSITY ]]
  then
    errEcho "$@"
  fi
}

function logCommand {
  verbose $COMMAND_VERBOSITY "command: $@"
}

function logOutput {
  verbose $OUTPUT_VERBOSITY "output:"
  verbose $OUTPUT_VERBOSITY "$@"
}

function error {
  echo >&2 "error: $@"
}

function fatal {
  error "$@"
  abort
}

# Use to log regular commands
# - command is logged to stderr if VERBOSITY is COMMAND_VERBOSITY or higher
# - command output is logged to stderr if VERBOSITY is OUTPUT_VERBOSITY or higher
# - stderr is not suppressed; failure exits the script
function cmd {
  set -e
  logCommand "$@"
  OUTPUT=$("$@")
  logOutput "$OUTPUT"
}

# Use to log regular commands that can fail
# - command is logged to stderr if VERBOSITY is COMMAND_VERBOSITY or higher
# - command output is logged to stderr if VERBOSITY is OUTPUT_VERBOSITY or higher
# - stderr is suppressed and a failure will not exit the script
function cmdTry {
  set +e
  logCommand "$@"
  OUTPUT=$("$@" 2>&1)
  logOutput "$OUTPUT"
  set -e
}

# Use to log command substitutions or regular commands when output should be displayed to the user
# - command is logged to stderr if VERBOSITY is COMMAND_VERBOSITY or higher
# - command output is logged to stderr if VERBOSITY is OUTPUT_VERBOSITY or higher
# - stderr is not suppressed; failure exits the script
# - stdout is "returned"
function sub {
  set -e
  logCommand "$@"
  OUTPUT=$("$@")
  logOutput "$OUTPUT"
  echo "$OUTPUT"
}

# Use to log command substitutions when only interested in exit code
# - command is logged to stderr if VERBOSITY is COMMAND_VERBOSITY or higher
# - command stdout and stderr are logged to stderr if VERBOSITY is OUTPUT_VERBOSITY or higher
# - stderr is suppressed and does not fail the script; "returns" exit code
function subRC {
  set +e
  logCommand $@
  OUTPUT=$("$@" 2>&1)
  RC=$?
  logOutput "$OUTPUT"
  set -e
  echo $RC
}

# Use to log command substitutions, ignoring errors
# - command is logged to stderr if VERBOSITY is COMMAND_VERBOSITY or higher
# - command stdout and stderr are logged to stderr if VERBOSITY is OUTPUT_VERBOSITY or higher
# - stdout is "returned" if command exits successfully
function subIf {
  set +e
  logCommand $@
  OUTPUT=$("$@" 2>&1)
  RC=$?
  logOutput "$OUTPUT"
  if [[ $RC -eq 0 ]]
  then
    echo $OUTPUT
  fi
  set -e
}

# nd = new directory
function nd() {
  pushd $1 > /dev/null
}

# od = old directory
function od() {
  popd > /dev/null
}

function notConfigured {
  fatal "user.env file not found"
}

[[ -f $DIR/user.env ]] || notConfigured
. $DIR/user.env

function notLoggedIn {
  error "not logged in to $CLUSTERPOOL_CLUSTER"
  verbose 0 "Opening $CLUSTERPOOL_CONSOLE"
  sleep 3
  open $CLUSTERPOOL_CONSOLE
  abort
}

function notImplemented {
  error "${FUNCNAME[1]} not implemented"
  abort
}

# Creates and logs in as a new ServiceAccount in the cluster pool target namespace
# Account is named for the current user
function newServiceAccount {
  local user=$1
  local serviceAccount=$(echo "$user" | tr A-Z a-z)
  verbose 0 "Creating ServiceAccount $serviceAccount"
  cmdTry oc create -f - << EOF
kind: ServiceAccount
apiVersion: v1
metadata:
  name: $serviceAccount
  namespace: $CLUSTERPOOL_TARGET_NAMESPACE
EOF
  verbose 1 "Looking up token secret"
  local tokenSecret=$(sub oc -n $CLUSTERPOOL_TARGET_NAMESPACE get ServiceAccount $serviceAccount -o json | jq -r '.secrets | map(select(.name | test("token")))[0] | .name')
  verbose 1 "Extracting token"
  local token=$(sub oc -n $CLUSTERPOOL_TARGET_NAMESPACE get Secret $tokenSecret -o json | jq -r '.data.token' | base64 --decode)
  verbose 0 "Logging in as ServiceAccount $serviceAccount"
  cmd oc login --token $token --server $CLUSTERPOOL_CLUSTER
}

# Renames the current context to 'cm', making sure to use a ServiceAccount
# Can use pre-existing account or create a new one
function createCMContext {
  local server=$(subIf oc whoami --show-server)
  if [[ $server != $CLUSTERPOOL_CLUSTER || $(subRC oc status) -ne 0 ]]
  then
    notLoggedIn
  else
    local user=$(subIf oc whoami)
    if ! [[ $user =~ ^system:serviceaccount:${CLUSTERPOOL_TARGET_NAMESPACE}: ]]
    then
      newServiceAccount $user
    fi

    verbose 0 "Renaming current context to \"cm\""
    verbose 1 "(server=$server user=$user namespace=$CLUSTERPOOL_TARGET_NAMESPACE)"
    cmdTry oc config delete-context cm
    cmd oc config rename-context $(oc config current-context) cm
    cmd oc config set-context cm --namespace $CLUSTERPOOL_TARGET_NAMESPACE
  fi
}

# Verifies CM context is set up; runs only once per execution
function verifyCMContext {
  if [[ -z $CM_CONTEXT_VERIFIED && $(subRC oc config get-contexts cm) -ne 0  || $(subRC oc --context cm status) -ne 0 ]]
  then
    createCMContext
  fi
  export CM_CONTEXT_VERIFIED="true"
}

# Runs an oc command in the cluster manager context
function ocWithCMContext {
  verifyCMContext
  sub oc --context cm "$@"
}

# Runs any command in the cluster manager context
function withCMContext {
  local kubeconfig=$(mktemp)
  ocWithCMContext config view --minify --flatten > $kubeconfig
  export KUBECONFIG="$kubeconfig"
  "$@"
  unset KUBECONFIG
  rm "$kubeconfig"
}

# Resolves a dependency on another open-cluster-management project
function dependency {
  local dependencies="$DIR/dependencies"
  local localDep="$dependencies/$1"
  if [[ -f "$localDep" ]]
  then
    nd $(dirname "$localDep")
    verbose 1 "Updating $localDep"
    cmdTry git pull
    od
    echo $localDep
    return 0
  else
    local gitBase=$(subIf dirname $(git remote get-url origin))
    if [[ -n $gitBase ]]
    then
      local depName=$(echo "$1" | cut -d / -f 1)
      local depRepo=$gitBase/${depName}.git
      mkdir -p "$dependencies"
      nd "$dependencies"
      verbose 0 "Cloning $depRepo"
      cmdTry git clone $depRepo
      od
      if [[ -f "$localDep" ]]
      then
        echo $localDep
        return 0
      fi
    fi
  fi

  local siblingDep="$DIR/../$1"
  if [[ -f "$siblingDep" ]]
  then
    echo $siblingDep
    return 0
  fi

  fatal "Missing dependency: $1"
}

# Resolves a file within a dependency
# Does not fetch or update the dependency
function dependencyFile {
  local dependencies="$DIR/dependencies"
  local localDep="$dependencies/$1"
  local siblingDep="$DIR/../$1"
  if [[ -f "$localDep" ]]
  then
    echo $localDep
    return 0
  elif [[ -f "$siblingDep" ]]
  then
    echo $siblingDep
    return 0
  else
    return 1
  fi
}

# Runs the given command in its own directory
function dirSensitiveCmd {
  local cmdDir=$(dirname "$1")
  nd "$cmdDir"
  $1
  od
}

function getClusterDeployment {
  local clusterClaim=$1
  local required=$2
  local clusterDeployment
  clusterDeployment=$(ocWithCMContext get ClusterClaim $clusterClaim -o jsonpath='{.spec.namespace}')
  if [[ -z $clusterDeployment && -n $required ]]
  then
    fatal "The ClusterClaim $clusterClaim has not been assigned a ClusterDeployment"
  fi
  echo $clusterDeployment
}

function waitForClusterDeployment {
  # Verify that the claim exists and wait for ClusterDeployment
  local count=0
  until [[ -n "$clusterDeployment" || $count -gt $CLUSTER_WAIT_MAX ]]
  do
    local clusterDeployment
    clusterDeployment=$(ocWithCMContext get ClusterClaim $1 -o jsonpath='{.spec.namespace}')
    count=$(($count + 1))

    if [[ -z $clusterDeployment && $count -le $CLUSTER_WAIT_MAX ]]
    then
      verbose 0 "Waiting up to $CLUSTER_WAIT_MAX min for ClusterDeployment ($count/$CLUSTER_WAIT_MAX)..."
      sleep 60
    fi
  done

  echo $clusterDeployment
}

function getHibernation {
  ocWithCMContext get ClusterClaim $1 -o jsonpath='{.metadata.annotations.open-cluster-management\.io/cluster-manager-hibernation}'
}

function getHolds {
  ocWithCMContext get ClusterClaim $1 -o jsonpath='{.metadata.annotations.open-cluster-management\.io/cluster-manager-holds}'
}

function checkHolds {
  holds=$(getHolds $1)
  if [[ -n $holds ]]
  then
    verbose 0 "Cluster is held by: $holds"
    fatal "Cannot operate on held cluster; use -f to force"
  fi
}

function setPowerState {
  local claim=$1
  local state=$2
  local force=$3
  clusterDeployment=$(getClusterDeployment $claim "required")
  if [[ -z $force ]]
  then
    checkHolds $claim
  fi
  verbose 0 "Setting power state to $state on ClusterDeployment $clusterDeployment"
  local deploymentPatch=$(cat << EOF
- op: add
  path: /spec/powerState
  value: $state
EOF
  )
  ocWithCMContext -n $clusterDeployment patch ClusterDeployment $clusterDeployment --type json --patch "$deploymentPatch" > /dev/null
}

function enableServiceAccounts {
  local claim=$1
  verifyCMContext
  claimServiceAccountSubjects=$(sub oc --context cm get ClusterClaim $claim -o json | jq -r ".spec.subjects | map(select(.name == \"system:serviceaccounts:${CLUSTERPOOL_TARGET_NAMESPACE}\")) | length")
  if [[ $claimServiceAccountSubjects -le 0 ]]
  then
    verbose 0 "Adding namespace service accounts as a claim subject"
    local claimPatch=$(cat << EOF
- op: add
  path: /spec/subjects/-
  value:
    apiGroup: rbac.authorization.k8s.io
    kind: Group
    name: system:serviceaccounts:$CLUSTERPOOL_TARGET_NAMESPACE
EOF
    )
    cmd oc --context cm  patch ClusterClaim $claim --type json --patch "$claimPatch"
  fi
}

function enableSchedule {
  local claim=$1
  local force=$2
  local clusterDeployment
  clusterDeployment=$(waitForClusterDeployment $claim)

  if [[ -z $force ]]
  then
    checkHolds $claim
  fi

  verbose 0 "Enabling scheduled hibernation/resumption for $claim"
  local hibernateValue="true"
  if [[ -n $(getHolds $claim) ]]
  then
    hibernateValue="skip"
  fi

  local ensureAnnotations=$(cat << EOF
- op: test
  path: /metadata/annotations
  value: null
- op: add
  path: /metadata/annotations
  value: { "open-cluster-management.io/cluster-manager-hibernation": "true" }
EOF
  )
  local claimPatch=$(cat << EOF
- op: add
  path: /metadata/annotations/open-cluster-management.io~1cluster-manager-hibernation
  value: "true"
EOF
  )
  verbose 1 "Annotating ClusterClaim $claim"
  cmdTry oc --context cm patch ClusterClaim $claim --type json --patch "$ensureAnnotations"
  cmd oc --context cm patch ClusterClaim $claim --type json --patch "$claimPatch"
  
  local deploymentPatch=$(cat << EOF
- op: add
  path: /metadata/labels/hibernate
  value: "$hibernateValue"
EOF
  )
  verbose 1 "Opting-in for hibernation on ClusterDeployment $clusterDeployment"
  cmd oc --context cm  -n $clusterDeployment patch ClusterDeployment $clusterDeployment --type json --patch "$deploymentPatch"
}

function disableSchedule {
  local claim=$1
  local force=$2
  local clusterDeployment
  clusterDeployment=$(waitForClusterDeployment $claim)

  if [[ -z $force ]]
  then
    checkHolds $claim
  fi

  verbose 0 "Disabling scheduled hibernation/resumption for $claim"
  local removeAnnotation=$(cat << EOF
- op: remove
  path: /metadata/annotations/open-cluster-management.io~1cluster-manager-hibernation
EOF
  )
  verbose 1 "Removing annotation on ClusterClaim $claim"
  cmdTry oc --context cm patch ClusterClaim $claim --type json --patch "$removeAnnotation"

  local deploymentPatch=$(cat << EOF
- op: add
  path: /metadata/labels/hibernate
  value: "skip"
EOF
  )
  verbose 1 "Opting-out for hibernation on ClusterDeployment $clusterDeployment"
  cmd oc --context cm  -n $clusterDeployment patch ClusterDeployment $clusterDeployment --type json --patch "$deploymentPatch"
}

function addHold {
  notImplemented
}

function releaseHold {
  notImplemented
}

function displayCreds {
  local context=$1
  local fetch_fresh=$2
  local credsFile=$(subIf dependencyFile lifeguard/clusterclaims/${1}/${1}.creds.json)
  if [[ -z "$credsFile" || -n "$fetch_fresh" ]]
  then
    getCreds $@
    credsFile=$(subIf dependencyFile lifeguard/clusterclaims/${1}/${1}.creds.json)
  fi
  cat "$credsFile"
}

function getCreds {
  waitForClusterDeployment $1 > /dev/null

  # Use lifeguard/clusterclaims/get_credentials.sh to get the credentionals for the cluster
  export CLUSTERCLAIM_NAME=$1
  export CLUSTERPOOL_TARGET_NAMESPACE
  withCMContext dirSensitiveCmd $(dependency lifeguard/clusterclaims/get_credentials.sh)
}
