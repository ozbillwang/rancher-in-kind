#!/usr/bin/env bash
#
# RKIND is a naive helper script to start KIND and Rancher Management Server
# Forked with updates from https://gist.github.com/anapsix/25a5a66696f14806a4686ec1c707d2d2

set -u
set -o pipefail

RANCHER_CONTAINER_NAME="rancher-for-kind"
RANCHER_HTTP_HOST_PORT=$[$[RANDOM%9000]+30000]
RANCHER_HTTPS_HOST_PORT=$[$[RANDOM%9000]+30000]
: ${KIND_CLUSTER_NAME:="kind-for-rancher"}

COLOR_OFF='\033[0m'
GREEN='\033[0;92m'
YELLOW='\033[0;33m'
PURPLE='\033[0;95m'
RED='\033[0;91m'

RANCHER_VERSION=2.6.2

info() {
  if [[ ${QUIET:-0} -eq 0 ]] || [[ ${DEBUG:-0} -eq 1 ]]; then
    echo >&2 -e "${GREEN}INFO:${COLOR_OFF} $@"
  fi
}

warn() {
  if [[ ${QUIET:-0} -eq 0 ]] || [[ ${DEBUG:-0} -eq 1 ]]; then
    echo >&2 -e "${YELLOW}WARNING:${COLOR_OFF} $@"
  fi
}

debug(){
  if [[ ${DEBUG:-0} -eq 1 ]]; then
    echo >&2 -e "${PURPLE}DEBUG:${COLOR_OFF} $@"
  fi
}

error(){
  local msg="$1"
  local exit_code="${2:-1}"
  echo >&2 -e "${RED}ERROR:${COLOR_OFF} $1"
  if [[ "${exit_code}" != "-" ]]; then
    exit ${exit_code}
  fi
}

getval() {
  local x="${1%%=*}"
  if [[ "$x" = "$1" ]]; then
    echo "${2}"
    return 2
  else
    echo "${1##*=}"
    return 1
  fi
}

usage() {
cat <<EOF
Usage: $0 [FLAGS] [ACTIONS]
  FLAGS:
    -h | --help | --usage   displays usage
    -q | --quiet            enabled quiet mode, no output except errors
    --debug                 enables debug mode, ignores quiet mode
  ACTIONS:
    create                create new Rancher & Kind cluster
    destroy               destroy Rancher & Kind cluster created by this script
  Examples:
    \$ $0 create
    \$ $0 destroy

EOF
}

case $(uname -s) in
  Darwin)
    localip="$(ipconfig getifaddr en0)"
  ;;
  Linux)
    localip="$(hostname -i)"
  ;;
  *)
    echo >&2 "Unsupported OS, exiting.."
    exit 1
  ;;
esac

## Get CLI arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help|--usage)
      usage
      exit 0
    ;;

    -d|--debug)
      DEBUG=1
      shift 1
    ;;

    -q|--quiet)
      QUIET=1
      shift 1
    ;;

    create|init)
      MODE="create"
      shift 1
    ;;

    destroy|cleanup)
      MODE="destroy"
      shift 1
    ;;

    *)
      error "Unexpected option \"$1\"" -
      usage
      exit 1
    ;;
  esac
done

set -e

# check docker binary availability
if ! which docker >/dev/null; then
  error "Docker binary cannot be found in PATH" -
  error "Install Docker or check your PATH, exiting.."
fi

# check KIND binary availability
if ! which kind >/dev/null; then
  error "KIND binary is missing" -
  error "Install it with \"go get sigs.k8s.io/kind\"" -
  error "Or download appropriate binary from https://github.com/kubernetes-sigs/kind/releases" -
  error "For more details see:" -
  error " - https://kind.sigs.k8s.io" -
  error " - https://github.com/kubernetes-sigs/kind" -
  error "exiting.."
fi

if [[ "${MODE:-}" == "destroy" ]]; then
  info "Destroying Rancher container.."
  if ! docker rm -f ${RANCHER_CONTAINER_NAME}; then
    error "failed to remove Rancher container \"${RANCHER_CONTAINER_NAME}\".." -
  fi
  info "Destroying Kind cluster.."
  if ! kind delete cluster --name ${KIND_CLUSTER_NAME}; then
    error "failed to delete Kind cluster \"${KIND_CLUSTER_NAME}\".." -
  fi
  exit 0
elif [[ "${MODE:-}" != "create" ]]; then
  usage
  exit 0
fi

# Launch Rancher server
if [[ $(docker ps -f name=${RANCHER_CONTAINER_NAME} -q | wc -l) -ne 0 ]]; then
  error "Rancher container already present, delete it before trying again, exiting.."
fi
info "Launching Rancher container"
if RANCHER_CONTAINER_ID=$(docker run -d \
              --privileged \
              --restart=unless-stopped \
              --name ${RANCHER_CONTAINER_NAME}  \
              -p ${RANCHER_HTTP_HOST_PORT}:80   \
              -p ${RANCHER_HTTPS_HOST_PORT}:443 \
              rancher/rancher:v${RANCHER_VERSION} 2>&1); then
  info "Rancher UI will be available at https://${localip}:${RANCHER_HTTPS_HOST_PORT}"
  info "It might take few up to 60 seconds for Rancher UI to become available.."
  info "While it's coming up, going to start KIND cluster"
fi

echo $RANCHER_CONTAINER_ID

# Start KIND cluster
if [[ $(kind get clusters | grep -c ${KIND_CLUSTER_NAME}) -ne 0 ]]; then
  warn "KIND cluster is already running.."
  echo >&2 -n "Use running KIND? [y/N] "
  read use_running_kind
  case $use_running_kind in
    n|N)
      echo >&2 "exiting.."
      exit 1
    ;;
    y|Y)
      echo >&2 "ok, continuing.."
    ;;
    *)
      error "unrecognized option, exiting.."
    ;;
  esac
else
  info "Creating Kind cluster ..."
  kind create cluster --name ${KIND_CLUSTER_NAME} --config kind.yaml
fi

cat >&2 <<EOM
### Next steps ###
- Setup admin credentials in Rancher UI
- Set "Rancher Server URL" to "https://${localip}:${RANCHER_HTTPS_HOST_PORT}" (should already be selected)
  you may change it at any time in "Settings"
- wait for 2 minute
- Import KIND cluster to Rancher (via https://${localip}:${RANCHER_HTTPS_HOST_PORT}/g/clusters/add?provider=import)
  (select "Import Existing cluster" when adding a cluster)
  > To work around "Unable to connect to the server: x509: certificate signed by unknown authority"
  > use "curl --insecure" which is provided by Rancher UI to get the manifest, piping it's output to, for example:

    curl --insecure -sfL https://${localip}:${RANCHER_HTTPS_HOST_PORT}/v3/import/6qbm7q9lk7gmqsgt4l2hrrchlxbfh6fjskzb8tx84mjrl9jvhb8xcm.yaml | kubectl apply -f -

- set context to kind cluster 

kubectl cluster-info --context kind-${KIND_CLUSTER_NAME}

### Destroy
To shut everything down, use "$0 destroy", or manually with
docker rm -f ${RANCHER_CONTAINER_NAME}; kind delete cluster ${KIND_CLUSTER_NAME}
EOM

echo https://${localip}:${RANCHER_HTTPS_HOST_PORT} > rancher_url_$(date +%Y%m%d%H%M)

# set Rancher admin password and add kind cluster
bash -x ./add-cluster.sh "${localip}:${RANCHER_HTTPS_HOST_PORT}" "${KIND_CLUSTER_NAME}" "${RANCHER_CONTAINER_ID}"

# Open Rancher UI in browser
open https://${localip}:${RANCHER_HTTPS_HOST_PORT}
