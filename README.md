# Cluster Keeper
<img align="right" src="logo.png" alt="a hibernating bear hugs a cluster" width="256px" />

Cluster Keeper provides a CLI for managing usage of multiple OpenShift clusters via [Hive](https://github.com/openshift/hive) `ClusterPools`, `ClusterClaims`, and `ClusterDeployments`.
It is compatible with scheduled hibernation provided by [hibernate-cronjob](https://github.com/open-cluster-management/hibernate-cronjob).

With the `ck` CLI you can:
- List and get ClusterPools, ClusterClaims, and ClusterDeployments
- Create and delete clusters
- Run and hibernate clusters manually
- Lock clusters to temporarily disable scheduled hibernation and other disruptive actions
- Switch your kubeconfig context between clusters or run a single command in a given context
- Launch the OpenShift or Advanced Cluster Management consoles and have the password automatically copied to the clipboard for easy log-in

When any command requires communication with a cluster, Cluster Keeper will resume the cluster if it is currently hibernating (unless it is currently locked).

Except for the `ck use` command, Cluster Keeper will never change your current kubeconfig context. But Cluster Keeper creates a context for each cluster named according to the ClusterClaim. For any command that takes the name of a ClusterClaim, Cluster Keeper will infer it from the current context if it is not provided.

Cluster Keeper leverages [Lifeguard](https://github.com/open-cluster-management/lifeguard) for many functions, but it sets the environment variables for you and does not require you to change directories.

## Installation

1. Clone the repository. For example:
   ```
   git clone git@github.com:open-cluster-management/cluster-keeper.git
   ```
1. (_Optional, but highly recommended_) Create a symlink to `ck` on your path. For example:
   ```
   ln -s $(pwd)/ck /usr/local/bin/ck
   ```
1. Make sure you have all the [dependencies](#dependencies).

## Dependencies

- `bash` 
   - version 4 or newer
   - on macOS with [Homebrew](https://brew.sh/) installed, run `brew install bash`. This bash must be first in your path, but need not be `/bin/bash` or your default login shell.
- `oc` version 4.3 or newer
- `jq`
  - on macOS with [Homebrew](https://brew.sh/) installed, run `brew install jq`
- `gsed`
  - required by [Lifeguard](https://github.com/open-cluster-management/lifeguard) for macOS only
  - with [Homebrew](https://brew.sh/) installed, run `brew install gnu-sed`
- Other projects from the `open-cluster-management` organization. (If you have `git` configured for CLI access, these will be automatically cloned to the `dependencies/` directory. Otherwise, you can manually clone these projects to the same directory where you cloned `cluster-keeper`.)
  - [Lifeguard](https://github.com/open-cluster-management/lifeguard)

## Configuration

In your clone of `cluster-keeper`, create a `user.env` file.
Each line in this file has the form `VARIABLE=value` and will be sourced directly. You must set the required variables

### Required Variables
| Name | Description |
|------|-------------|
|`CLUSTERPOOL_CLUSTER`|The API address of the cluster where your `ClusterPools` are defined. Also referred to as the "ClusterPool host"|
|`CLUSTERPOOL_CONSOLE`|The URL of the OpenShift console for the ClusterPool host|
|`CLUSTERPOOL_TARGET_NAMESPACE`|Namespace where `ClusterPools` are defined|
|`CLUSTERCLAIM_GROUP_NAME`|Name of a `Group` (`user.openshift.io/v1`) that should be added to each `ClusterClaim` for team access|

### Optional Variables
| Name | Default | Description |
|------|---------|-------------|
|`AUTO_HIBERNATION`|`true`|If value is `true`, all new clusters are configured to opt-in to hibernation by [hibernate-cronjob](https://github.com/open-cluster-management/hibernate-cronjob)|
|`CLUSTER_WAIT_MAX`|`60`|Maximum wait time in minutes for a `ClusterDeployment` to be assigned to the `ClusterClaim` when requesting a new cluster|
|`HIBERNATE_WAIT_MAX`|`15`|Maximum wait time in minutes for a cluster to resume from hibernation|
|`VERBOSITY`|`0`|Default verbosity level|
|`COMMAND_VERBOSITY`|`2`|Verbosity level at which commands are logged|
|`OUTPUT_VERBOSITY`|`3`|Verbosity level at which command output is logged|
|`CLUSTERPOOL_CONTEXT_NAME`|`ck`|Context name for the ClusterPool host itself|
## Usage
On first use, Cluster Keeper will check if you are logged in to the ClusterPool host. If not, you will be prompted to log in and the OpenShift console will be opened. Copy the log-in command, run it in your terminal, then try your `ck` command again. Cluster Keeper will create a `ServiceAccount` on the ClusterPool host for you, then update your kubeconfig with a context for the ClusterPool host that uses this `ServiceAccount`. By default, the context is named `ck`. Now you can execute `ck` commands without needing to continually log in to the ClusterPool host.

Online help is available directly from the CLI using the global `-h` option.

[View Usage](./USAGE.md)

### Moving between teams
If you are moving from one team to another (between namespaces), you need to clean up the service account in the first namespace, and `ck` will create a user account for you in the second. Make sure you have permission to work with both projects.

1. Connect to the OpenShift hosting the cluster pools
2. Set your project to the original project (`oc project <PROJECT_NAME`) you were using to provision with cluster keeper
3. Search for the service account that was being used in this project (`oc get sa`)
4. Delete the service account once locate it (`oc delete sa SA_NAME`)
5. Now update the user.env file, with the new `CLUSTERPOOL_TARGET_NAMESPACE` and `CLUSTERCLAIM_GROUP_NAME`
6. Run a `ck` command, and a new service account will be setup in your new project, similar to what is described above in `Usage`
