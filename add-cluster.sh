#!/bin/bash

set -ex

# Forked with updates from https://gist.githubusercontent.com/superseb/c363247c879e96c982495daea1125276/raw/98d9c0590992f2b7e209ae4e0a7da7da1db5aee0/rancher2customnodecmd.sh

URL="$1"
KIND_CLUSTER_NAME="$2"
PASSWORD="password"

while ! cURL -k "https://${URL}/ping"; do sleep 3; done

# Login
LOGINRESPONSE=`cURL -s "https://${URL}/v3-public/localProviders/local?action=login" -H 'content-type: application/json' --data-binary '{"username":"admin","password":"admin"}' --insecure`
LOGINTOKEN=`echo $LOGINRESPONSE | jq -r .token`
echo ${LOGINTOKEN}

# Change password
cURL -s "https://${URL}/v3/users?action=changepassword" -H 'content-type: application/json' -H "Authorization: Bearer $LOGINTOKEN" --data-binary '{"currentPassword":"admin","newPassword":"'${PASSWORD}'"}' --insecure

LOGINRESPONSE=`cURL -s "https://${URL}/v3-public/localProviders/local?action=login" -H 'content-type: application/json' --data-binary '{"username":"admin","password":"'${PASSWORD}'"}' --insecure`
LOGINTOKEN=`echo $LOGINRESPONSE | jq -r .token`
echo ${LOGINTOKEN}

# Create API key
APIRESPONSE=`cURL -s "https://${URL}/v3/token" -H 'content-type: application/json' -H "Authorization: Bearer $LOGINTOKEN" --data-binary '{"type":"token","description":"automation"}' --insecure`
# Extract and store token
APITOKEN=`echo $APIRESPONSE | jq -r .token`
echo ${APITOKEN}

# Configure server-URL
RANCHER_SERVER="${URL}"
cURL -s "https://${URL}/v3/settings/server-URL" -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" -X PUT --data-binary '{"name":"server-URL","value":"'https://$RANCHER_SERVER'"}' --insecure

# Create cluster
CLUSTERRESPONSE=`cURL -s "https://${URL}/v3/cluster" -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --data-binary '{"type":"cluster","nodes":[],"rancherKubernetesEngineConfig":{"ignoreDockerVersion":true},"name":"'${KIND_CLUSTER_NAME}'"}' --insecure`
# Extract clusterid to use for generating the docker run command
CLUSTERID=`echo $CLUSTERRESPONSE | jq -r .id`
echo ${CLUSTERID}

# Generate token (clusterRegistrationToken) and extract nodeCommand
AGENTCOMMAND=`cURL -s "https://${URL}/v3/clusters/${CLUSTERID}/clusterregistrationtoken" -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --data-binary '{"type":"clusterRegistrationToken","clusterId":"'$CLUSTERID'"}' --insecure | jq -r .insecureCommand`

# Show the command
echo "${AGENTCOMMAND}"

# add the kind cluster
kubectl cluster-info --context kind-${KIND_CLUSTER_NAME}
"${AGENTCOMMAND}"

# export the cluster detail
echo "Rancher admin password is: ${PASSWORD}"
echo "Rancher URL is ${URL}"
echo "Rancher account: admin / ${PASSWORD}"
