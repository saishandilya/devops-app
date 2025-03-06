#!/bin/bash

DOCKER_CONFIG_JSON=$1
VALUES_FILE=$2

# Update the dockerconfigjson field in values.yaml
sed -i "s|dockerconfigjson: \"\"|dockerconfigjson: \"$DOCKER_CONFIG_JSON\"|" "$VALUES_FILE"
