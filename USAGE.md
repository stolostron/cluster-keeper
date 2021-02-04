# Usage
### Index
* [cm](#cm)
  * [acm](#cm-acm)
  * [console](#cm-console)
  * [creds](#cm-creds)
  * [current](#cm-current)
  * [delete](#cm-delete)
  * [disable-schedule](#cm-disable-schedule)
  * [enable-sa](#cm-enable-sa)
  * [enable-schedule](#cm-enable-schedule)
  * [get](#cm-get)
  * [hibernate](#cm-hibernate)
  * [list](#cm-list)
  * [lock](#cm-lock)
  * [new](#cm-new)
  * [pw](#cm-pw)
  * [run](#cm-run)
  * [state](#cm-state)
  * [unlock](#cm-unlock)
  * [use](#cm-use)
  * [with](#cm-with)
### Commands

## cm 
```
usage: cm [OPTIONS] SUBCOMMAND

    SUBCOMMAND is one of the following.

    acm
        Launch the ACM console for current or given context
    console
        Launch the OpenShift console for current or given context
    creds
        Display credentials for a cluster
    current
        Display the current kubeconfig context
    delete
        Delete a cluster by deleting its ClusterClaim
    disable-schedule
        Disable scheduled hibernation/resumption for current or given cluster
    enable-sa
        Enable namespace service accounts for current or given cluster
    enable-schedule
        Enable scheduled hibernation/resumption for current or given cluster
    get
        Get a ClusterPool, ClusterClaim, or ClusterDeployment
    hibernate
        Hibernate a cluster
    list
        List ClusterPools, ClusterClaims, and ClusterDeployments
    lock
        Lock a cluster
    new
        Get a new cluster by creating a ClusterClaim
    pw
        Copy a cluster password to the clipboard
    run
        Resume a hibernating cluster
    state
        Get the power state of a cluster
    unlock
        Unlock a cluster
    use
        Switch kubeconfig context
    with
        Run any command with the given context

    The following OPTIONS are available:

    -h    Display usage for SUBCOMMAND
    -v    Verbosity level for information printed to stderr. Default: 0
```
<sup><sub>[🔝 Back to top](#usage)</sub></sup>

## cm acm
```
usage: cm acm [CONTEXT]

    Launch the ACM console for current or given context
    If the context matches a ClusterClaim, the kubeadmin password is copied to the clipboard

    CONTEXT is the name of a kubeconfig context
        'cm' context refers to the ClusterPool host
```
<sup><sub>[🔝 Back to top](#usage)</sub></sup>

## cm console
```
usage: cm console [CONTEXT]

    Launch the OpenShift console for current or given context
    If the context matches a ClusterClaim, the kubeadmin password is copied to the clipboard

    CONTEXT is the name of a kubeconfig context
        'cm' context refers to the ClusterPool host
```
<sup><sub>[🔝 Back to top](#usage)</sub></sup>

## cm creds
```
usage: cm creds [OPTIONS] [CONTEXT]

    Display credentials for a cluster
    CAUTION: This will display the admin password.

    CONTEXT is the name of a kubeconfig context that matches a ClusterClaim

    The following OPTIONS are available:

    -r    Refresh the credentials by fetching a fresh copy
```
<sup><sub>[🔝 Back to top](#usage)</sub></sup>

## cm current
```
usage: cm current

    Display the current kubeconfig context
```
<sup><sub>[🔝 Back to top](#usage)</sub></sup>

## cm delete
```
usage: cm delete [OPTIONS] [CONTEXT]

    Delete a cluster by deleting its ClusterClaim

    CONTEXT is the name of a kubeconfig context that matches a ClusterClaim

    The following OPTIONS are available:

    -f    Force operation if cluster is currently locked
    -y    Delete without confirmation
```
<sup><sub>[🔝 Back to top](#usage)</sub></sup>

## cm disable-schedule
```
usage: cm disable-schedule [OPTIONS] [CONTEXT]

    Disable scheduled hibernation/resumption for current or given cluster

    CONTEXT is the name of a kubeconfig context that matches a ClusterClaim

    The following OPTIONS are available:

    -f    Force operation if cluster is currently locked
```
<sup><sub>[🔝 Back to top](#usage)</sub></sup>

## cm enable-sa
```
usage: cm enable-sa [OPTIONS] [CONTEXT]

    Enable namespace service accounts for current or given cluster
    Run if you do not have permission to edit the ClusterDeployment for a ClusterClaim

    CONTEXT is the name of a kubeconfig context that matches a ClusterClaim
```
<sup><sub>[🔝 Back to top](#usage)</sub></sup>

## cm enable-schedule
```
usage: cm enable-schedule [OPTIONS] [CONTEXT]

    Enable scheduled hibernation/resumption for current or given cluster

    CONTEXT is the name of a kubeconfig context that matches a ClusterClaim

    The following OPTIONS are available:

    -f    Force operation if cluster is currently locked
```
<sup><sub>[🔝 Back to top](#usage)</sub></sup>

## cm get
```
usage: cm get pool|claim|cluster [NAME] [ARGS]

    Get a ClusterPool, ClusterClaim, or ClusterDeployment
    Each resource type supports a number of aliases (singular and plural)
    and is case-insensitve

    pool (cp, ClusterPool)
    claim (cc, ClusterClaim)
    cluster (cd, ClusterDeployment)

    NAME is the name of the resource or the related ClusterClaim
        if omitted, the current kubeconfig context is used if it matches a ClusterClaim
    ARGS are additional args passed through to 'oc get' such as '-o yaml'
```
<sup><sub>[🔝 Back to top](#usage)</sub></sup>

## cm hibernate
```
usage: cm hibernate [CONTEXT]

    Hibernate a cluster

    CONTEXT is the name of a kubeconfig context that matches a ClusterClaim

    The following OPTIONS are available:

    -f    Force operation if cluster is currently locked
```
<sup><sub>[🔝 Back to top](#usage)</sub></sup>

## cm list
```
usage: cm list pools|claims|clusters

    List ClusterPools, ClusterClaims, and ClusterDeployments
    Each resource type supports a number of aliases (singular and plural)
    and is case-insensitve

    pools (cp, ClusterPool)
    claims (cc, ClusterClaim)
    clusters (cd, ClusterDeployment)
```
<sup><sub>[🔝 Back to top](#usage)</sub></sup>

## cm lock
```
usage: cm lock [OPTIONS] [CONTEXT]

    Lock a cluster
    A locked cluster will not be hibernated/resumed on schedule
    Other users are prevented from running certain subcommands on locked
    clusters, like 'cm run', 'cm hibernate', and 'cm delete'

    CONTEXT is the name of a kubeconfig context that matches a ClusterClaim

    The following OPTIONS are available:

    -i    Use the provided lock ID instead of username
```
<sup><sub>[🔝 Back to top](#usage)</sub></sup>

## cm new
```
usage: cm new [OPTIONS] POOL CLAIM

    Get a new cluster by creating a ClusterClaim

    POOL is the name of the ClusterPool
    CLAIM is the name for the new ClusterClaim

    The following OPTIONS are available:

    -l    Lifetime of the cluster in hours
    -m    Manual power management; do not enable scheduled hibernation
```
<sup><sub>[🔝 Back to top](#usage)</sub></sup>

## cm pw
```
usage: cm pw [OPTIONS] [CONTEXT]

    Copy a cluster password to the clipboard
    CAUTION: This will display the admin password.

    CONTEXT is the name of a kubeconfig context that matches a ClusterClaim

    The following OPTIONS are available:

    -r    Refresh the credentials by fetching a fresh copy
```
<sup><sub>[🔝 Back to top](#usage)</sub></sup>

## cm run
```
usage: cm run [CONTEXT]

    Resume a hibernating cluster

    CONTEXT is the name of a kubeconfig context that matches a ClusterClaim

    The following OPTIONS are available:

    -f    Force operation if cluster is currently locked
```
<sup><sub>[🔝 Back to top](#usage)</sub></sup>

## cm state
```
usage: cm state [CONTEXT]

    Get the power state of a cluster

    CONTEXT is the name of a kubeconfig context that matches a ClusterClaim
```
<sup><sub>[🔝 Back to top](#usage)</sub></sup>

## cm unlock
```
usage: cm unlock [OPTIONS] [CONTEXT]

    Unlock a cluster
    Removes a lock from a cluster
    If you remove the last lock, you may wish to hibernate the cluster

    CONTEXT is the name of a kubeconfig context that matches a ClusterClaim

    The following OPTIONS are available:

    -a    Remove all locks
    -i    Use the provided lock ID instead of username
```
<sup><sub>[🔝 Back to top](#usage)</sub></sup>

## cm use
```
usage: cm use CONTEXT

    Switch kubeconfig context
    If the context matches a ClusterClaim and the cluster is currently
    hibernating, it is resumed

    CONTEXT is the name of a kubeconfig context
        'cm' context refers to the ClusterPool host

    -f    Force operation if cluster is currently locked
```
<sup><sub>[🔝 Back to top](#usage)</sub></sup>

## cm with
```
usage: cm with CONTEXT COMMAND

    Run any command with the given context
    If the context matches a ClusterClaim and the cluster is currently
    hibernating, it is resumed

    CONTEXT is the name of a kubeconfig context
        'cm' context refers to the ClusterPool host
    COMMAND is any command, such as a script that invokes oc or kubectl

    -f    Force operation if cluster is currently locked
```
<sup><sub>[🔝 Back to top](#usage)</sub></sup>
