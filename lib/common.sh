# Copyright Contributors to the Open Cluster Management project

# nd = new directory
function nd() {
  pushd $1 > /dev/null
}

# od = old directory
function od() {
  popd > /dev/null
}

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
function newCKServiceAccount {
  local user=$1
  local serviceAccount=$(echo "$user" | tr '[:upper:]' '[:lower:]' | tr -cd "[:alnum:]-_")
  verbose 0 "Creating ServiceAccount $serviceAccount"
  cmdTry oc -n $CLUSTERPOOL_TARGET_NAMESPACE create serviceaccount $serviceAccount
  verbose 1 "Creating token secret"
  local tokenSecret="${serviceAccount}-token"
  cmdTry oc -n $CLUSTERPOOL_TARGET_NAMESPACE create secret generic $tokenSecret
  verbose 1 "Creating token"
  local token=$(sub oc -n $CLUSTERPOOL_TARGET_NAMESPACE create token $serviceAccount --bound-object-kind Secret --bound-object-name $tokenSecret --duration 8760h)
  verbose 0 "Logging in as ServiceAccount $serviceAccount"
  cmd oc login --token $token --server $CLUSTERPOOL_CLUSTER
}

# Sets up a context
function createContext {
  local context="$1"
  verbose 0 "Creating context $context"

  if [[ $context == $CLUSTERPOOL_CONTEXT_NAME ]]
  then
    createCKContext
    return $?
  fi

  # Make sure cluster is running
  setPowerState "$context" "Running"
  ignoreOutput waitForClusterDeployment $1 "Running"

  local kubeconfig kubeconfig_temp
  kubeconfig=$(getCredsFile "$context" "lifeguard/clusterclaims/${context}/kubeconfig" "true")
  verbose 0 "Preparing kubeconfig $kubeconfig"
  local kubeconfig_temp=$(mktemp)
  cp $kubeconfig $kubeconfig_temp
  
  # Rename admin context to match ClusterClaim name
  cmd oc --kubeconfig $kubeconfig_temp config rename-context "$(KUBECONFIG=$kubeconfig_temp oc config current-context)" "$context"
  
  # Export the client certificate and key to temporary files
  local adminUserJson
  adminUserJson=$(oc --kubeconfig $kubeconfig_temp config view --flatten -o json | jq -r '.users[] | select(.name == "admin") | .user')
  local clientCertificate=$(mktemp)
  local clientKey=$(mktemp)
  echo "$adminUserJson" | jq -r '.["client-certificate-data"]' | base64 --decode > "$clientCertificate"
  echo "$adminUserJson" | jq -r '.["client-key-data"]' | base64 --decode > "$clientKey"
  
  # Create new user with name to match ClusterClaim
  cmd oc --kubeconfig $kubeconfig_temp config set-credentials $context --client-certificate "$clientCertificate" --client-key "$clientKey"
  
  # Update context to use new user and delete old user
  cmd oc --kubeconfig $kubeconfig_temp config set-context $context --user $context
  cmd oc --kubeconfig $kubeconfig_temp config unset users.admin

  # Create ServiceAccount and ClusterRoleBinding in order to obtain token
  local user=$(getUsername)
  verbose 0 "Creating ServiceAccount $user"
  cmdTry oc --kubeconfig $kubeconfig_temp -n default create serviceaccount $user
  verbose 1 "Creating ClusterRoleBinding $user"
  cmdTry oc --kubeconfig $kubeconfig_temp create clusterrolebinding $user --clusterrole=cluster-admin --serviceaccount=default:$user
  verbose 1 "Creating token secret"
  local tokenSecret="${user}-token"
  cmdTry oc --kubeconfig $kubeconfig_temp create secret generic $tokenSecret -n default
  verbose 1 "Creating token"
  local token=$(sub oc --kubeconfig $kubeconfig_temp -n default create token $user --bound-object-kind Secret --bound-object-name $tokenSecret --duration 8760h)
  cmd oc --kubeconfig $kubeconfig_temp config set-credentials $context --token $token

  # Generate flattened ClusterClaim kubeconfig
  oc --kubeconfig $kubeconfig_temp config view --flatten > "$kubeconfig"

  local timestamp=$(date "+%s")
  local user_kubeconfig="${HOME}/.kube/config"
  local new_user_kubeconfig="${user_kubeconfig}.new"
  local backup_user_kubeconfig="${user_kubeconfig}.backup-${timestamp}"
  verbose 0 "Backing up $user_kubeconfig to $backup_user_kubeconfig"
  cmd cp "$user_kubeconfig" "$backup_user_kubeconfig"
  # Copy existing kubeconfig to .new to preserve permissions
  cmd cp "$user_kubeconfig" "$new_user_kubeconfig"

  # Remove pre-existing context and user from user kubeconfig
  cmdTry oc config delete-context $context
  cmdTry oc config unset users.${context}
  
  # Generate flattened user kubeconfig and delete temp files
  KUBECONFIG="${user_kubeconfig}:${kubeconfig}" oc config view --flatten > "$new_user_kubeconfig"
  cmd rm "$clientCertificate" "$clientKey" "$kubeconfig_temp"
  
  cmd mv "$new_user_kubeconfig" "$user_kubeconfig"
  verbose 0 "${user_kubeconfig} updated with new context $context"
}

# Renames the current context to '$CLUSTERPOOL_CONTEXT_NAME', making sure to use a ServiceAccount
# Can use pre-existing account or create a new one
function createCKContext {
  local server=$(subIf oc whoami --show-server)
  if [[ $server != $CLUSTERPOOL_CLUSTER || $(subRC oc status) -ne 0 ]]
  then
    notLoggedIn
  else
    local user=$(subIf oc whoami)
    if ! [[ $user =~ ^system:serviceaccount:${CLUSTERPOOL_TARGET_NAMESPACE}: ]]
    then
      newCKServiceAccount $user
    fi

    verbose 0 "Renaming current context to \"$CLUSTERPOOL_CONTEXT_NAME\""
    verbose 1 "(server=$server user=$user namespace=$CLUSTERPOOL_TARGET_NAMESPACE)"
    cmdTry oc config delete-context $CLUSTERPOOL_CONTEXT_NAME
    cmd oc config rename-context $(oc config current-context) $CLUSTERPOOL_CONTEXT_NAME
    cmd oc config set-context $CLUSTERPOOL_CONTEXT_NAME --namespace $CLUSTERPOOL_TARGET_NAMESPACE
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
      # context does not exist; try to create it if it is '$CLUSTERPOOL_CONTEXT_NAME' or corresponds to a ClusterClaim
      if [[ "$context" == "$CLUSTERPOOL_CONTEXT_NAME" || -n $(getClusterClaim "$context") ]]
      then
        createContext "$context"
      fi
    else
      if [[ "$context" != "$CLUSTERPOOL_CONTEXT_NAME" && -n $(getClusterClaim "$context") ]]
      then
        # Make sure cluster is running
        setPowerState "$context" "Running"
        ignoreOutput waitForClusterDeployment "$context" "Running"
      fi

      if [[ $(subRC oc --context "$context" get serviceaccounts --request-timeout 10s) -ne 0 ]]
      then
        # context may be out-of-date
        createContext "$context"
      fi
    fi

    # Context should now exist and be reachable; fail otherwise
    ignoreOutput oc config get-contexts "$context"
    ignoreOutput oc --context "$context" get serviceaccounts --request-timeout 10s
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

# Resolves a dependency on another stolostron project
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
  ./$(basename $1)
  od
}

function getClusterClaim {
  local name=$1
  local required=$2
  # Check for cluster claim only if context name does not contain / or :
  if ! [[ "$name" =~ [/:] ]]
  then
    local clusterClaim
    clusterClaim=$(subIf oc --context $CLUSTERPOOL_CONTEXT_NAME get clusterclaims.hive $name -o jsonpath='{.metadata.name}')
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
  clusterPool=$(subIf oc --context $CLUSTERPOOL_CONTEXT_NAME get clusterclaims.hive $clusterClaim -o jsonpath='{.spec.clusterPoolName}')
  if [[ -z $clusterPool && -n $required ]]
  then
    fatal "The ClusterClaim $clusterClaim does not have a ClusterPool"
  fi
  echo $clusterPool
}

function getClusterDeployment {
  local clusterClaim=$1
  local required=$2
  local clusterDeployment
  clusterDeployment=$(subIf oc --context $CLUSTERPOOL_CONTEXT_NAME get clusterclaims.hive $clusterClaim -o jsonpath='{.spec.namespace}')
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
    clusterDeployment=$(ocWithContext $CLUSTERPOOL_CONTEXT_NAME get clusterclaims.hive "$clusterClaim" -o jsonpath='{.spec.namespace}')
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
      conditionsJson=$(ocWithContext $CLUSTERPOOL_CONTEXT_NAME -n $clusterDeployment get clusterdeployments.hive $clusterDeployment -o json  | jq -r '.status.conditions')
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
  ocWithContext $CLUSTERPOOL_CONTEXT_NAME get clusterclaims.hive $1 -o jsonpath='{.metadata.annotations.open-cluster-management\.io/cluster-keeper-hibernation}'
}

function getLocks {
  ocWithContext $CLUSTERPOOL_CONTEXT_NAME get clusterclaims.hive $1 -o jsonpath='{.metadata.annotations.open-cluster-management\.io/cluster-keeper-locks}'
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
  
  powerState=$(ocWithContext $CLUSTERPOOL_CONTEXT_NAME -n $clusterDeployment get clusterdeployments.hive $clusterDeployment -o json | jq -r '.spec.powerState')
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
    ignoreOutput ocWithContext $CLUSTERPOOL_CONTEXT_NAME -n $clusterDeployment patch clusterdeployments.hive $clusterDeployment --type json --patch "$deploymentPatch"
  else
    verbose 1 "Power state is already $powerState on ClusterDeployment $clusterDeployment"
  fi
}

function enableServiceAccounts {
  local claim=$1
  claimServiceAccountSubjects=$(sub oc --context $CLUSTERPOOL_CONTEXT_NAME get clusterclaims.hive $claim -o json | jq -r ".spec.subjects | map(select(.name == \"system:serviceaccounts:${CLUSTERPOOL_TARGET_NAMESPACE}\")) | length")
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
    cmd oc --context $CLUSTERPOOL_CONTEXT_NAME patch clusterclaims.hive $claim --type json --patch "$claimPatch"
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
  cmd oc --context $CLUSTERPOOL_CONTEXT_NAME  -n $clusterDeployment patch clusterdeployments.hive $clusterDeployment --type json --patch "$deploymentPatch"
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
  value: { "open-cluster-management.io/cluster-keeper-hibernation": "true" }
EOF
  )
  local claimPatch=$(cat << EOF
- op: add
  path: /metadata/annotations/open-cluster-management.io~1cluster-keeper-hibernation
  value: "true"
EOF
  )
  verbose 1 "Annotating ClusterClaim $claim"
  cmdTry oc --context $CLUSTERPOOL_CONTEXT_NAME patch clusterclaims.hive $claim --type json --patch "$ensureAnnotations"
  cmd oc --context $CLUSTERPOOL_CONTEXT_NAME patch clusterclaims.hive $claim --type json --patch "$claimPatch"
  
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
  cmd oc --context $CLUSTERPOOL_CONTEXT_NAME -n $clusterDeployment patch clusterdeployments.hive $clusterDeployment --type json --patch "$deploymentPatch"
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
  path: /metadata/annotations/open-cluster-management.io~1cluster-keeper-hibernation
EOF
  )
  verbose 1 "Removing annotation on ClusterClaim $claim"
  cmdTry oc --context $CLUSTERPOOL_CONTEXT_NAME patch clusterclaims.hive $claim --type json --patch "$removeAnnotation"

  disableHibernation $claim
}

function getUsername {
  ocWithContext $CLUSTERPOOL_CONTEXT_NAME whoami | rev | cut -d : -f 1 | rev
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

  ocWithContext $CLUSTERPOOL_CONTEXT_NAME get clusterclaims.hive "$context" -o json | jq -r ".metadata.annotations[\"open-cluster-management.io/cluster-keeper-locks\"] |= (. // \"\" | split(\",\") + [\"$lockId\"] | unique | join(\",\"))" | ocWithContext $CLUSTERPOOL_CONTEXT_NAME replace -f -
  disableHibernation $context
}

function removeLock {
  local context="$1"
  local lockId=$(getLockId "$2")
  local allLocks="$3"
  if [[ -n "$allLocks" ]]
  then
    verbose 0 "Removing all locks on $context"
    ocWithContext $CLUSTERPOOL_CONTEXT_NAME get clusterclaims.hive "$context" -o json | jq -r ".metadata.annotations[\"open-cluster-management.io/cluster-keeper-locks\"] |= \"\"" | ocWithContext $CLUSTERPOOL_CONTEXT_NAME replace -f -
  else
    verbose 0 "Removing lock on $context for $lockId"
    ocWithContext $CLUSTERPOOL_CONTEXT_NAME get clusterclaims.hive "$context" -o json | jq -r ".metadata.annotations[\"open-cluster-management.io/cluster-keeper-locks\"] |= (. // \"\" | split(\",\") - [\"$lockId\"] | unique | join(\",\"))"   | ocWithContext $CLUSTERPOOL_CONTEXT_NAME replace -f -
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
  ignoreOutput waitForClusterDeployment $1
  verbose 0 "Fetching credentials for ${1}"
  # Use lifeguard/clusterclaims/get_credentials.sh to get the credentionals for the cluster
  export CLUSTERCLAIM_NAME=$1
  export CLUSTERPOOL_TARGET_NAMESPACE
  ignoreOutput withContext $CLUSTERPOOL_CONTEXT_NAME dirSensitiveCmd $(dependency lifeguard/clusterclaims/get_credentials.sh)
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
  if [[ $days -gt 0 ]]
  then
    result="${days}d"
  fi
  if [[ $days -lt 7 && $hours -gt 0 ]]
  then
    result="${result}${hours}h"
  fi
  if [[ $days -eq 0 && $hours -lt 24 && $minutes -gt 0 ]]
  then
    result="${result}${minutes}m"
  fi
  if [[ $days -eq 0 && $hours -eq 0 && $minutes -lt 60 && $seconds -gt 0 ]]
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
  clusterDeployments="$(ocWithContext $CLUSTERPOOL_CONTEXT_NAME get clusterdeployments.hive -A -L hibernate 2> /dev/null)\n"
  
  # Process ClusterDeployment lines and index POWERSTATE and HIBERNATE by NAME
  while IFS='' read -r line
  do
    if [[ -z $powerstateIndex ]]
    then
      # Header line; find index of POWERSTATE and HIBERNATE columns
      powerstateIndex=$(indexOf "$line" POWERSTATE)
      hibernateIndex=$(indexOf "$line" HIBERNATE)
    else 
      # Data lines; map POWERSTATE and HIBERNATE
      cdName=$(firstField $line)
      powerstateMap[$cdName]=${line:${powerstateIndex}:11} # Longest states are 11 characters (Unsupported, Hibernating)
      hibernateMap[$cdName]="${line:${hibernateIndex}:4}" # All values are 4 characters (true, skip) 
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
      # All hibernate values are 4 characters (true, skip), so add 2 to cover <none>
      line=$(replaceString "$line" "${hibernateMap[$clusterName]}  " $hibernateIndex)
    fi
    if [[ $(uname) = Darwin ]]
    then
      timestamp=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "${line:$ageIndex}" "+%s")
    else
      timestamp=$(date -u -d "${line:$ageIndex}" "+%s")
    fi
    age=$(getAge $((currentTimestamp - timestamp)))
    line=$(replaceString "$line" "$age" $ageIndex)
    echo "${line:0:$((ageIndex + ${#age}))}"
  done
}