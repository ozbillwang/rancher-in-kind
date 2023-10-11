# Usage

This repo is to create rancher and add [kind](https://github.com/kubernetes-sigs/kind) (Kubernetes IN Docker) into Rancher automatically with all-in-one script

* Create Rancher UI
* create Kind Kubernetes cluster
* Init rancher admin’s password
* update server url in rancher
* import kind cluster into rancher

![image](https://user-images.githubusercontent.com/8954908/141780177-a81ddc31-a144-47ad-b9a0-2fc5bce8bbda.png)

### Notes

Rancher API keeps changing, currently we hard code the rancher version to version "v2.6.2"

### Prerequisite

1) Make sure you have installed Kind (kubernetes in docker) locally.

The installation instruction is here: https://kind.sigs.k8s.io/docs/user/quick-start/

2) Adjust docker engine memory

Default docker engine is set to use 2GB runtime memory, adjust it to 8GB+ if you can.

3) review `kind.yaml`

Currently I only set one worker node, you can add more if you need.

```
$ cat kind.yaml.template
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
  extraMounts:
  - hostPath: ./data
    containerPath: /data
- role: worker
  extraMounts:
  - hostPath: ./data
    containerPath: /data
- role: worker
  extraMounts:
  - hostPath: ./data
    containerPath: /data
```

with this way, you can share the local directoy `./data` to all nodes as persistent volume.

### Get help

```
$ ./rkind.sh
Usage: ./rkind.sh [FLAGS] [ACTIONS]
  FLAGS:
    -h | --help | --usage   displays usage
    -q | --quiet            enabled quiet mode, no output except errors
    --debug                 enables debug mode, ignores quiet mode
  ACTIONS:
    create                create new Rancher & Kind cluster
    destroy               destroy Rancher & Kind cluster created by this script
  Examples:
    $ ./rkind.sh create
    $ ./rkind.sh destroy

Update kind (kuberentes in docker) configuration in local kind.yaml (https://kind.sigs.k8s.io/)
```

### Create the stack

```
$ ./rkind.sh create
```
### destroy the stack

```
$ ./rkind.sh destroy
```

### custom kind configuration

If you'd like to change the kind configuration, please update file [kind.yaml](kind.yaml). For details, go through https://kind.sigs.k8s.io/
