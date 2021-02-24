# Cluster Keeper

Cluster Keeper provides a CLI for managing squad usage of multiple OpenShift clusters via [Hive](https://github.com/openshift/hive) `ClusterPools`, `ClusterClaims`, and `ClusterDeployments`. It is compatible with scheduled hibernation provided by [hibernate-cronjob](https://github.com/open-cluster-management/hibernate-cronjob).

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
   git clone git@github.com:open-cluster-management/cluster-manager.git
   ```
1. Create a personal configuration file by copying one of the defaults provided.
   ```
   cd cluster-manager
   cp user.app-squad user.env
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
- Other projects from the `open-cluster-management` organization. (If you have `git` configured for CLI access, these will be automatically cloned to the `dependencies/` directory. Otherwise, you can manually clone these projects to the same directory where you cloned `cluster-manager`.)
  - [Lifeguard](https://github.com/open-cluster-management/lifeguard)

## Usage

Online help is available directly from the CLI using the global `-h` option.

[View Usage](./USAGE.md)
