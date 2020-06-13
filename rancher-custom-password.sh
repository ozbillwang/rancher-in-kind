#!/bin/bash

# Forked with updates from https://gist.githubusercontent.com/superseb/c363247c879e96c982495daea1125276/raw/98d9c0590992f2b7e209ae4e0a7da7da1db5aee0/rancher2customnodecmd.sh

url="$1"

while ! curl -k "https://${url}/ping"; do sleep 3; done

# Login
LOGINRESPONSE=`curl -s "https://${url}/v3-public/localProviders/local?action=login" -H 'content-type: application/json' --data-binary '{"username":"admin","password":"admin"}' --insecure`
LOGINTOKEN=`echo $LOGINRESPONSE | jq -r .token`
echo ${LOGINTOKEN}

# Change password
curl -s "https://${url}/v3/users?action=changepassword" -H 'content-type: application/json' -H "Authorization: Bearer $LOGINTOKEN" --data-binary '{"currentPassword":"admin","newPassword":"thisisyournewpassword"}' --insecure

# Create API key
APIRESPONSE=`curl -s "https://${url}/v3/token" -H 'content-type: application/json' -H "Authorization: Bearer $LOGINTOKEN" --data-binary '{"type":"token","description":"automation"}' --insecure`
# Extract and store token
APITOKEN=`echo $APIRESPONSE | jq -r .token`
echo ${APITOKEN}

# Configure server-url
RANCHER_SERVER="${url}"
curl -s 'https://${url}/v3/settings/server-url' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" -X PUT --data-binary '{"name":"server-url","value":"'https://$RANCHER_SERVER'"}' --insecure

# Create cluster
CLUSTERRESPONSE=`curl -s "https://${url}/v3/cluster" -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --data-binary '{"type":"cluster","nodes":[],"rancherKubernetesEngineConfig":{"ignoreDockerVersion":true},"name":"yournewcluster"}' --insecure`
# Extract clusterid to use for generating the docker run command
CLUSTERID=`echo $CLUSTERRESPONSE | jq -r .id`
echo ${CLUSTERID}

# Generate token (clusterRegistrationToken) and extract nodeCommand
AGENTCOMMAND=`curl -s "https://${url}/v3/clusterregistrationtoken" -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --data-binary '{"type":"clusterRegistrationToken","clusterId":"'$CLUSTERID'"}' --insecure | jq -r .insecureCommand`

# Show the command
echo "${AGENTCOMMAND}"

# add the kind cluster
kubectl cluster-info --context kind-kind-for-rancher
eval ${AGENTCOMMAND}

