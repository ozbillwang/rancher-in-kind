# Usage

This repo is used to create rancher and add a kubernetes cluster with kind (kubernetes in docker) in Rancher.

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

Update kind (kuberentes in docker) configuration in kind.yaml (https://kind.sigs.k8s.io/)
```

### Create the stack

```
$ ./rkind.sh --create
INFO: Launching Rancher container
cec8ff9b437bfe9234c56001a21fe5d9ba8423e182d25ab6dbe0f2b06f92308b
INFO: Rancher UI will be available at https://192.168.1.100:33486
INFO: It might take few up to 60 seconds for Rancher UI to become available..
INFO: While it's coming up, going to start KIND cluster
No kind clusters found.
INFO: Creating Kind cluster..
Creating cluster "kind-for-rancher" ...
 ✓ Ensuring node image (kindest/node:v1.17.0) 🖼
 ✓ Preparing nodes 📦 📦 📦 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-kind-for-rancher"
You can now use your cluster with:

kubectl cluster-info --context kind-kind-for-rancher

Have a nice day! 👋
### Next steps ###
- Setup admin credentials in Rancher UI
- Set "Rancher Server URL" to "https://192.168.1.100:33486" (should already be selected)
  you may change it at any time in "Settings"
- Import KIND cluster to Rancher (via https://192.168.1.100:33486/g/clusters/add?provider=import)
  (select "Import Existing cluster" when adding a cluster)
> To work around "Unable to connect to the server: x509: certificate signed by unknown authority"
> use "curl --insecure" to get the manigest, piping it's output to
> KUBECONFIG="$(kind get kubeconfig-path --name=kind-for-rancher)" kubectl apply -f -
To shut everything down, use "./rkind.sh cleanup", or manually with
docker rm -f rancher-for-kind; kind delete cluster kind-for-rancher
```
### destroy the stack

```
$ ./rkind.sh --destroy
INFO: Destroying Rancher container..
rancher-for-kind
INFO: Destroying Kind cluster..
Deleting cluster "kind-for-rancher" ...
```

### custom kind configuration

If you'd like to change the kind configuration, please update its file [kind.yaml](kind.yaml). For details, go through https://kind.sigs.k8s.io/
