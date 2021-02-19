VERBOSITY=0
AUTO_HIBERNATION=true
COMMAND_VERBOSITY=2
OUTPUT_VERBOSITY=3
CLUSTER_WAIT_MAX=60
HIBERNATE_WAIT_MAX=15

VERIFIED_CONTEXTS=()

CLUSTERCLAIM_CUSTOM_COLUMNS="\
NAME:.metadata.name,\
CLUSTER:.spec.namespace,\
POWERSTATE:PLACEHOLDER,\
LOCKS:.metadata.annotations.open-cluster-management\.io/cluster-manager-locks,\
SCHEDULE:.metadata.annotations.open-cluster-management\.io/cluster-manager-hibernation,\
HIBERNATE:PLACEHOLDER,\
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

# Use to silence output when not using "return" value from a function
function ignoreOutput {
  "$@" > /dev/null
}

# Use to log regular commands
# - command is logged to stderr if VERBOSITY is COMMAND_VERBOSITY or higher
# - command output is logged to stderr if VERBOSITY is OUTPUT_VERBOSITY or higher
# - stderr is not suppressed; failure exits the script
function cmd {
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
  echo -n $RC
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
function newCMServiceAccount {
  local user=$1
  local serviceAccount=$(echo "$user" | tr A-Z a-z)
  verbose 0 "Creating ServiceAccount $serviceAccount"
  cmdTry oc -n $CLUSTERPOOL_TARGET_NAMESPACE create serviceaccount $serviceAccount
  verbose 1 "Looking up token secret"
  local tokenSecret=$(sub oc -n $CLUSTERPOOL_TARGET_NAMESPACE get ServiceAccount $serviceAccount -o json | jq -r '.secrets | map(select(.name | test("token")))[0] | .name')
  verbose 1 "Extracting token"
  local token=$(sub oc -n $CLUSTERPOOL_TARGET_NAMESPACE get Secret $tokenSecret -o json | jq -r '.data.token' | base64 --decode)
  verbose 0 "Logging in as ServiceAccount $serviceAccount"
  cmd oc login --token $token --server $CLUSTERPOOL_CLUSTER
}

# Sets up a context
function createContext {
  local context="$1"
  verbose 0 "Creating context $context"

  if [[ $context == cm ]]
  then
    createCMContext
    return $?
  fi

  local kubeconfig
  kubeconfig=$(getCredsFile "$context" "lifeguard/clusterclaims/${context}/kubeconfig" "true")
  verbose 0 "Preparing kubeconfig $kubeconfig"
  
  # Rename admin context to match ClusterClaim name
  cmd oc --kubeconfig $kubeconfig config rename-context "$(KUBECONFIG=$kubeconfig oc config current-context)" "$context"
  
  # Export the client certificate and key to temporary files
  local adminUserJson
  adminUserJson=$(oc --kubeconfig $kubeconfig config view --flatten -o json | jq -r '.users[] | select(.name == "admin") | .user')
  local clientCertificate=$(mktemp)
  local clientKey=$(mktemp)
  echo "$adminUserJson" | jq -r '.["client-certificate-data"]' | base64 --decode > "$clientCertificate"
  echo "$adminUserJson" | jq -r '.["client-key-data"]' | base64 --decode > "$clientKey"
  
  # Create new user with name to match ClusterClaim, then clean up temp files
  cmd oc --kubeconfig $kubeconfig config set-credentials $context --client-certificate "$clientCertificate" --client-key "$clientKey"
  
  # Update context to use new user and delete old user
  cmd oc --kubeconfig $kubeconfig config set-context $context --user $context
  cmd oc --kubeconfig $kubeconfig config unset users.admin

  # Create ServiceAccount and ClusterRoleBinding in order to obtain token
  local user=$(getUsername)
  verbose 0 "Creating ServiceAccount $user"
  cmdTry oc --kubeconfig $kubeconfig -n default create serviceaccount $user
  verbose 1 "Creating ClusterRoleBinding $user"
  cmdTry oc --kubeconfig $kubeconfig create clusterrolebinding $user --clusterrole=cluster-admin --serviceaccount=default:$user
  verbose 1 "Looking up token secret"
  local tokenSecret=$(sub oc --kubeconfig $kubeconfig -n default get ServiceAccount $user -o json | jq -r '.secrets | map(select(.name | test("token")))[0] | .name')
  verbose 1 "Extracting token"
  local token=$(sub oc --kubeconfig $kubeconfig -n default get Secret $tokenSecret -o json | jq -r '.data.token' | base64 --decode)
  cmd oc --kubeconfig $kubeconfig config set-credentials $context --token $token

  local timestamp=$(date "+%s")
  local user_kubeconfig="${HOME}/.kube/config"
  local new_user_kubeconfig="${user_kubeconfig}.new"
  local backup_user_kubeconfig="${user_kubeconfig}.backup-${timestamp}"
  verbose 0 "Backing up $user_kubeconfig to $backup_user_kubeconfig"
  cp "$user_kubeconfig" "$backup_user_kubeconfig"

  # Remove pre-existing context and user from user kubeconfig
  cmdTry oc config delete-context $context
  cmdTry oc config unset users.${context}
  
  # Generate flattened config and delete temp files
  KUBECONFIG="${user_kubeconfig}:${kubeconfig}" oc config view --flatten > "$new_user_kubeconfig"
  rm "$clientCertificate" "$clientKey"
  
  mv "$new_user_kubeconfig" "$user_kubeconfig"
  verbose 0 "${user_kubeconfig} updated with new context $context"
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
      newCMServiceAccount $user
    fi

    verbose 0 "Renaming current context to \"cm\""
    verbose 1 "(server=$server user=$user namespace=$CLUSTERPOOL_TARGET_NAMESPACE)"
    cmdTry oc config delete-context cm
    cmd oc config rename-context $(oc config current-context) cm
    cmd oc config set-context cm --namespace $CLUSTERPOOL_TARGET_NAMESPACE
  fi
}

# Verifies the given context is set up
function verifyContext {
  local context="$1"
  verbose 1 "Verifying context $context"
  local alreadyVerified powerState
  for i in "${VERIFIED_CONTEXTS[@]}"
  do
    if [[ $i == $context ]]
    then
      alreadyVerified="true"
    fi
  done
  if [[ -z $alreadyVerified ]]
  then
    verbose 1 "Context $context needs verification"
    if [[ $(subRC oc config get-contexts "$context") -ne 0 ]]
    then
      # context does not exist; try to create it if it is 'cm' or corresponds to a ClusterClaim
      if [[ "$context" == "cm" || -n $(getClusterClaim "$context") ]]
      then
        createContext "$context"
      fi
    else
      if [[ "$context" != "cm" && -n $(getClusterClaim "$context") ]]
      then
        # Make sure cluster is running
        setPowerState "$context" "Running"
        ignoreOutput waitForClusterDeployment "$context" "Running"
      fi

      if [[ $(subRC oc --context "$context" status --request-timeout 10s) -ne 0 ]]
      then
        # context may be out-of-date
        createContext "$context"
      fi
    fi

    # Context should now exist and be reachable; fail otherwise
    ignoreOutput oc config get-contexts "$context"
    ignoreOutput oc --context "$context" status --request-timeout 10s
    VERIFIED_CONTEXTS+="$context"
  fi
}

# Runs an oc command in the given context
function ocWithContext {
  local context=$1
  shift
  verifyContext "$context"
  sub oc --context "$context" "$@"
}

# Runs any command the given context
function withContext {
  local context="$1"
  shift
  local kubeconfig=$(mktemp)
  ocWithContext "$context" config view --minify --flatten > $kubeconfig
  KUBECONFIG="$kubeconfig" "$@"
  unset KUBECONFIG
  rm "$kubeconfig"
}

# Resolves a dependency on another open-cluster-management project
function dependency {
  local dependencies localDep gitBase depName depRepo
  dependencies="$DIR/dependencies"
  localDep="$dependencies/$1"
  if [[ -f "$localDep" ]]
  then
    nd $(dirname "$localDep")
    verbose 1 "Updating $localDep"
    cmdTry git pull
    od
    echo $localDep
    return 0
  else
    nd $DIR
    gitBase=$(subIf dirname $(git remote get-url origin))
    od
    if [[ -n $gitBase ]]
    then
      depName=$(echo "$1" | cut -d / -f 1)
      depRepo=$gitBase/${depName}.git
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

function getClusterClaim {
  local name=$1
  local required=$2
  # Check for cluster claim only if context name does not contain / or :
  if ! [[ "$name" =~ [/:] ]]
  then
    local clusterClaim
    clusterClaim=$(subIf oc --context cm get ClusterClaim $name -o jsonpath='{.metadata.name}')
  fi
  if [[ -z $clusterClaim && -n $required ]]
  then
    fatal "ClusterClaim $name not found"
  fi
  echo "$clusterClaim"
}

function getClusterPool {
  local clusterClaim=$1
  local required=$2
  local clusterPool
  clusterPool=$(subIf oc --context cm get ClusterClaim $clusterClaim -o jsonpath='{.spec.clusterPoolName}')
  if [[ -z $clusterPool && -n $required ]]
  then
    fatal "The ClusterClaim $clusterClaim does not have a ClusterPool"
  fi
  echo $clusterDeployment
}

function getClusterDeployment {
  local clusterClaim=$1
  local required=$2
  local clusterDeployment
  clusterDeployment=$(subIf oc --context cm get ClusterClaim $clusterClaim -o jsonpath='{.spec.namespace}')
  if [[ -z $clusterDeployment && -n $required ]]
  then
    fatal "The ClusterClaim $clusterClaim has not been assigned a ClusterDeployment"
  fi
  echo $clusterDeployment
}

function waitForClusterDeployment {
  local clusterClaim=$1
  local powerState=$2
  local count clusterDeployment conditionsJson
  local hibernating hibernatingReason unreachable
  local hibernatingDesired hibernatingReasonDesired unreachableDesired

  # Verify that the claim exists and wait for ClusterDeployment
  count=0
  until [[ -n "$clusterDeployment" || $count -gt $CLUSTER_WAIT_MAX ]]
  do
    clusterDeployment=$(ocWithContext cm get ClusterClaim "$clusterClaim" -o jsonpath='{.spec.namespace}')
    count=$(($count + 1))

    if [[ -z $clusterDeployment && $count -le $CLUSTER_WAIT_MAX ]]
    then
      verbose 0 "Waiting up to $CLUSTER_WAIT_MAX min for ClusterDeployment ($count/$CLUSTER_WAIT_MAX)..."
      sleep 60
    fi
  done


  # Wait for specific power state
  if [[ $powerState =~ Running|Hibernating ]]
  then
    if [[ $powerState == "Running" ]]
    then
      hibernatingDesired="False"
      hibernatingReasonDesired="Running|Unsupported"
      unreachableDesired="False"
    else
      hibernatingDesired="True"
      hibernatingReasonDesired="Hibernating"
      unreachableDesired="True"
    fi
    verbose 1 "(hibernatingDesired=$hibernatingDesired hibernatingReasonDesired=$hibernatingReasonDesired unreachableDesired=$unreachableDesired)"

    # Wait for cluster to reach desired state
    count=0
    until [[ $count -gt $HIBERNATE_WAIT_MAX || ($hibernating =~ $hibernatingDesired && $hibernatingReason =~ $hibernatingReasonDesired && $unreachable =~ $unreachableDesired) ]]
    do
      conditionsJson=$(ocWithContext cm -n $clusterDeployment get ClusterDeployment $clusterDeployment -o json  | jq -r '.status.conditions')
      hibernating=$(echo "$conditionsJson" | jq -r '.[] | select(.type == "Hibernating") | .status')
      hibernatingReason=$(echo "$conditionsJson" | jq -r '.[] | select(.type == "Hibernating") | .reason')
      unreachable=$(echo "$conditionsJson" | jq -r '.[] | select(.type == "Unreachable") | .status')
      count=$(($count + 1))

      verbose 1 "(hibernating=$hibernating hibernatingReason=$hibernatingReason unreachable=$unreachable)"

      if [[ $count -le $HIBERNATE_WAIT_MAX && ! ($hibernating =~ $hibernatingDesired && $hibernatingReason =~ $hibernatingReasonDesired && $unreachable =~ $unreachableDesired) ]]
      then
        verbose 0 "Waiting up to $HIBERNATE_WAIT_MAX min for ClusterDeployment to be $powerState ($count/$HIBERNATE_WAIT_MAX)..."
        sleep 60
      fi
    done
  fi

  echo $clusterDeployment
}

function getHibernation {
  ocWithContext cm get ClusterClaim $1 -o jsonpath='{.metadata.annotations.open-cluster-management\.io/cluster-manager-hibernation}'
}

function getLocks {
  ocWithContext cm get ClusterClaim $1 -o jsonpath='{.metadata.annotations.open-cluster-management\.io/cluster-manager-locks}'
}

function checkLocks {
  locks=$(getLocks $1)
  if [[ -n $locks ]]
  then
    verbose 0 "Cluster is locked by: $locks"
    if [[ -z $FORCE ]]
    then
      fatal "Cannot operate on locked cluster; use -f to force"
    fi
  fi
}

function setPowerState {
  local claim=$1
  local state=$2
  local powerState oppositeState deploymentPatch
  clusterDeployment=$(getClusterDeployment $claim "required")
  
  if [[ $state == "Hibernating" ]]
  then
    oppositeState="Running"
  elif [[ $state == "Running" ]]
  then
    oppositeState="Hibernating"
  fi
  
  powerState=$(ocWithContext cm -n $clusterDeployment get ClusterDeployment $clusterDeployment -o json | jq -r '.spec.powerState')
  if [[ $powerState != $state ]]
  then
    checkLocks $claim
    if [[ -n $oppositeState ]]
    then
      ignoreOutput waitForClusterDeployment $claim $oppositeState
    fi
    verbose 0 "Setting power state to $state on ClusterDeployment $clusterDeployment"
    deploymentPatch=$(cat << EOF
- op: add
  path: /spec/powerState
  value: $state
EOF
  )
    ignoreOutput ocWithContext cm -n $clusterDeployment patch ClusterDeployment $clusterDeployment --type json --patch "$deploymentPatch"
  else
    verbose 1 "Power state is already $powerState on ClusterDeployment $clusterDeployment"
  fi
}

function enableServiceAccounts {
  local claim=$1
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
    cmd oc --context cm patch ClusterClaim $claim --type json --patch "$claimPatch"
  fi
}

function enableHibernation {
  local claim=$1
  local hibernateValue=$2

  if [[ -z $hibernateValue ]]
  then
    hibernateValue="true"
  fi

  local clusterDeployment
  clusterDeployment=$(waitForClusterDeployment $claim)
  
  local deploymentPatch=$(cat << EOF
- op: add
  path: /metadata/labels/hibernate
  value: "$hibernateValue"
EOF
  )
  verbose 1 "Opting-in for hibernation on ClusterDeployment $clusterDeployment with hibernate=$hibernateValue"
  cmd oc --context cm  -n $clusterDeployment patch ClusterDeployment $clusterDeployment --type json --patch "$deploymentPatch"
}

function enableSchedule {
  local claim=$1
  local force=$2

  if [[ -z $force ]]
  then
    checkLocks $claim
  fi

  verbose 0 "Enabling scheduled hibernation/resumption for $claim"

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
  
  local hibernateValue="true"
  if [[ -n $(getLocks $claim) ]]
  then
    hibernateValue="skip"
  fi
  enableHibernation $claim $hibernateValue
}

function disableHibernation {
  local claim=$1

  local clusterDeployment
  clusterDeployment=$(waitForClusterDeployment $claim)
  
  local deploymentPatch=$(cat << EOF
- op: add
  path: /metadata/labels/hibernate
  value: "skip"
EOF
  )
  verbose 1 "Opting-out for hibernation on ClusterDeployment $clusterDeployment"
  cmd oc --context cm -n $clusterDeployment patch ClusterDeployment $clusterDeployment --type json --patch "$deploymentPatch"
}

function disableSchedule {
  local claim=$1
  local force=$2

  if [[ -z $force ]]
  then
    checkLocks $claim
  fi

  verbose 0 "Disabling scheduled hibernation/resumption for $claim"
  local removeAnnotation=$(cat << EOF
- op: remove
  path: /metadata/annotations/open-cluster-management.io~1cluster-manager-hibernation
EOF
  )
  verbose 1 "Removing annotation on ClusterClaim $claim"
  cmdTry oc --context cm patch ClusterClaim $claim --type json --patch "$removeAnnotation"

  disableHibernation $claim
}

function getUsername {
  ocWithContext cm whoami | rev | cut -d : -f 1 | rev
}

function getLockId {
  local lockId="$1"
  if [[ -z "$lockId" ]]
  then
    lockId=$(getUsername)
  fi
  echo "$lockId"
}

function addLock {
  local context="$1"
  local lockId=$(getLockId "$2")
  verbose 0 "Adding lock on $context for $lockId"

  ocWithContext cm get ClusterClaim "$context" -o json | jq -r ".metadata.annotations[\"open-cluster-management.io/cluster-manager-locks\"] |= (. // \"\" | split(\",\") + [\"$lockId\"] | unique | join(\",\"))" | ocWithContext cm replace -f -
  disableHibernation $context
}

function removeLock {
  local context="$1"
  local lockId=$(getLockId "$2")
  local allLocks="$3"
  if [[ -n "$allLocks" ]]
  then
    verbose 0 "Removing all locks on $context"
    ocWithContext cm get ClusterClaim "$context" -o json | jq -r ".metadata.annotations[\"open-cluster-management.io/cluster-manager-locks\"] |= \"\"" | ocWithContext cm replace -f -
  else
    verbose 0 "Removing lock on $context for $lockId"
    ocWithContext cm get ClusterClaim "$context" -o json | jq -r ".metadata.annotations[\"open-cluster-management.io/cluster-manager-locks\"] |= (. // \"\" | split(\",\") - [\"$lockId\"] | unique | join(\",\"))"   | ocWithContext cm replace -f -
  fi
  local locks=$(getLocks $1)
  if [[ -n $locks ]]
  then
    verbose 0 "Current locks: $locks"
  else
    local hibernation=$(getHibernation $context)
    local hibernateValue="true"
    if [[ $hibernation != "true" ]]
    then
      hibernateValue="skip"
    fi
    enableHibernation $context $hibernateValue
    verbose 0 "No locks remain. You may want to hibernate the cluster."
  fi
}

function getCredsFile {
  local context=$1
  local filename=$2
  local fetch_fresh=$3
  local credsFile=$(subIf dependencyFile "$filename")
  if [[ -z "$credsFile" || -n "$fetch_fresh" ]]
  then
    getCreds "$context"
    credsFile=$(subIf dependencyFile "$filename")
  fi
  echo "$credsFile"
}

function copyPW {
  local context=$1
  local fetch_fresh=$2
  local credsFile username
  credsFile=$(getCredsFile "$context" "lifeguard/clusterclaims/${context}/${context}.creds.json" "$fetch_fresh")
  username=$(cat "$credsFile" | jq -r '.username')
  cat "$credsFile" | jq -j '.password' | pbcopy
  verbose 0 "Password for $username copied to clipboard"
}

function showKubeconfig {
  local context=$1
  local fetch_fresh=$2
  getCredsFile "$context" "lifeguard/clusterclaims/${context}/kubeconfig" "$fetch_fresh"
}

function displayCreds {
  local context=$1
  local fetch_fresh=$2
  local credsFile
  credsFile=$(getCredsFile "$context" "lifeguard/clusterclaims/${context}/${context}.creds.json" "$fetch_fresh")
  cat "$credsFile"
}

function getCreds {
  local powerState
  setPowerState $1 "Running"
  ignoreOutput waitForClusterDeployment $1 "Running"
  verbose 0 "Fetching credentials for ${1}"
  # Use lifeguard/clusterclaims/get_credentials.sh to get the credentionals for the cluster
  export CLUSTERCLAIM_NAME=$1
  export CLUSTERPOOL_TARGET_NAMESPACE
  ignoreOutput withContext cm dirSensitiveCmd $(dependency lifeguard/clusterclaims/get_credentials.sh)
}

function firstField {
  echo $1
}

function indexOf {
  local before
  local container="$1"
  local search="$2"

  before=${container/${search}*/}
  echo ${#before}
}

function replaceString {
  local length
  local original="$1"
  local replacement="$2"
  local index="$3"
  length=${#replacement}
  echo "${original:0:${index}}${replacement}${original:$((index + length))}"
}

function getAge {
  local days hours minutes result
  local age=$1
  days=$((age / 86400))
  hours=$((age % 86400 / 3600))
  minutes=$((age % 3600 / 60))
  seconds=$((age % 60))
  result=""
  if [[ $days > 0 ]]
  then
    result="${days}d"
  fi
  if [[ $days < 7 && $hours > 0 ]]
  then
    result="${result}${hours}h"
  fi
  if [[ $days = 0 && $hours < 24 && $minutes > 0 ]]
  then
    result="${result}${minutes}m"
  fi
  if [[ $days = 0 && $hours = 0 && $minutes < 60 && $seconds > 0 ]]
  then
    result="${result}${seconds}s"
  fi
  echo $result
}

function enhanceClusterClaimOutput {
  local ageIndex clusterIndex  hibernateIndex powerstateIndex clusterWidth
  local clusterDeployments cdName clusterName
  local currentTimestamp timestamp age
  declare -A powerstateMap
  declare -A hibernateMap
  clusterDeployments="$(sub ocWithContext cm get ClusterDeployments -A -L hibernate)\n"
  
  # Process ClusterDeployment lines and index POWERSTATE and HIBERNATE by NAME
  while IFS='' read -r line
  do
    if [[ -z $powerstateIndex ]]
    then
      # Header line; find index of POWERSTATE and HIBERNATE columns
      powerstateIndex=$(indexOf "$line" POWERSTATE)
      hiberateIndex=$(indexOf "$line" HIBERNATE)
    else 
      # Data lines; map POWERSTATE and HIBERNATE
      cdName=$(firstField $line)
      powerstateMap[$cdName]=${line:${powerstateIndex}:11} # Longest states are 11 characters (Unsupported, Hibernating)
      hibernateMap[$cdName]="${line:${hiberateIndex}:4}  " # All values are 4 characters (true, skip), so add 2 to cover <none>
    fi
  done <<< $clusterDeployments

  # Process ClusterClaim lines, substituting in POWERSTATE and HIBERNATE
  IFS='' read -r line
  clusterIndex=$(indexOf "$line" CLUSTER)
  powerstateIndex=$(indexOf "$line" POWERSTATE)
  hibernateIndex=$(indexOf "$line" HIBERNATE)
  ageIndex=$(indexOf "$line" AGE)
  clusterWidth=$(($powerstateIndex - $clusterIndex))
  currentTimestamp=$(date "+%s")
  echo "$line"
  while IFS='' read -r line
  do
    clusterName=$(echo ${line:$clusterIndex:$clusterWidth})
    if [[ -n "${powerstateMap[$clusterName]}" ]]
    then
      line=$(replaceString "$line" "${powerstateMap[$clusterName]}" $powerstateIndex)
    fi
    if [[ -n "${hibernateMap[$clusterName]}" ]]
    then
      line=$(replaceString "$line" "${hibernateMap[$clusterName]}" $hibernateIndex)
    fi
    timestamp=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "${line:$ageIndex}" "+%s")
    age=$(getAge $((currentTimestamp - timestamp)))
    line=$(replaceString "$line" "$age" $ageIndex)
    echo "${line:0:$((ageIndex + ${#age}))}"
  done
}