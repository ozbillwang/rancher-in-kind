#!/bin/bash

#set -ex

# Forked with updates from https://gist.github.com/superseb/c363247c879e96c982495daea1125276/#file-rancher2customnodecmd-sh

URL="$1"
KIND_CLUSTER_NAME="${2:-kind-for-rancher}"
INIT_PASSWORD=$(docker exec -ti $3 reset-password |grep -v "New password" |sed 's/\r$//')
sleep 15
PASSWORD="password"

while ! curl -k "https://${URL}/ping"; do sleep 3; done

# Login
#curl -vvv "https://${URL}/v3-public/localProviders/local?action=login" -H 'content-type: application/json' --data-binary '{"username":"admin","password":"'${INIT_PASSWORD}'"}' --insecure
LOGINRESPONSE=`curl -s "https://${URL}/v3-public/localProviders/local?action=login" -H 'content-type: application/json' --data-binary '{"username":"admin","password":"'${INIT_PASSWORD}'"}' --insecure`
LOGINTOKEN=`echo $LOGINRESPONSE | jq -r .token`
echo ${LOGINTOKEN}

# Change password
curl -s "https://${URL}/v3/users?action=changepassword" -H 'content-type: application/json' -H "Authorization: Bearer $LOGINTOKEN" --data-binary '{"currentPassword":"'${INIT_PASSWORD}'","newPassword":"'${PASSWORD}'"}' --insecure

LOGINRESPONSE=`curl -s "https://${URL}/v3-public/localProviders/local?action=login" -H 'content-type: application/json' --data-binary '{"username":"admin","password":"'${PASSWORD}'"}' --insecure`
LOGINTOKEN=`echo $LOGINRESPONSE | jq -r .token`
echo ${LOGINTOKEN}

# Create API key
APIRESPONSE=`curl -s "https://${URL}/v3/token" -H 'content-type: application/json' -H "Authorization: Bearer $LOGINTOKEN" --data-binary '{"type":"token","description":"automation"}' --insecure`
# Extract and store token
APITOKEN=`echo $APIRESPONSE | jq -r .token`
echo ${APITOKEN}

# Configure server-url
RANCHER_SERVER="${URL}"
curl -s "https://${URL}/v3/settings/server-url" -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" -X PUT --data-binary '{"name":"server-URL","value":"'https://$RANCHER_SERVER'"}' --insecure

# Create cluster
CLUSTERRESPONSE=`curl -s "https://${URL}/v3/cluster" -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --data-binary '{"type":"cluster","name":"'${KIND_CLUSTER_NAME}'","import":true}' --insecure`

# Extract clusterid to use for generating the docker run command
CLUSTERID=`echo $CLUSTERRESPONSE | jq -r .id`
echo ${CLUSTERID}

# Generate token (clusterRegistrationToken) and extract nodeCommand
ID=`curl -s "https://${URL}/v3/clusters/${CLUSTERID}/clusterregistrationtoken" -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --data-binary '{"type":"clusterRegistrationToken","clusterId":"'$CLUSTERID'"}' --insecure |jq -r .id`

AGENTCOMMAND=`curl -s "https://${URL}/v3/clusters/${CLUSTERID}/clusterregistrationtoken/$ID" -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --insecure | jq -r .insecureCommand`
# Show the command
echo "${AGENTCOMMAND}"

# add the kind cluster
kubectl cluster-info --context kind-${KIND_CLUSTER_NAME}
eval "${AGENTCOMMAND}"

# export the cluster detail
echo "Rancher admin password is: ${PASSWORD}"
echo "Rancher URL is https://${URL}"
echo "Rancher account: admin / ${PASSWORD}"
