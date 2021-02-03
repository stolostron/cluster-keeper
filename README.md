# Cluster Manager

Cluster Manager provides a CLI for managing squad usage of multiple OpenShift clusters via Hive `ClusterPools` and `ClusterClaims`.

## Installation

1. Clone the repository.
   ```
   git clone git@github.com:open-cluster-management/cluster-manager.git
   ```
1. Create a personal configuration file by copying one of the defaults provided.
   ```
   cd cluster-manager
   cp user.app-squad user.env
   ```
1. (Optional) Create a symlink to `cm` on your path.
   ```
   ln -s $(pwd)/cm ~/bin/cm
   ```

## Scenarios

### Day 1

Roke clones the repository and changes to his local directory. He creates a symlink to the `cm` script from a directory on his path so he can use the CLI from any working directory.
```
ln -s $(pwd)/cm ~/bin/cm
```

Roke needs exclusive access to two clusters for his development work. First he checks which pools are available.
```
cm list pools
```
