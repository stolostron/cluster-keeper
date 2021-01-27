# Cluster Manager

Cluster Manager provides a CLI for managing squad usage of multiple OpenShift clusters via Hive `ClusterPools` and `ClusterClaims`.

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
