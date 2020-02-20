#!/bin/bash

# Script that generates the elixir client code to communicate with child chain and watcher services.
# Auto generated elixir client would be put directly under apps/ directory.
#
# The client come with a default base url from the swagger spec file.
# To connect to different environment, override the middleware in runtime: https://github.com/teamon/tesla#runtime-middleware

set -e

echo "Generate api client script starts..."

echo "------------------------------------------------------"
echo "Cleaning up .api_specs/ and generated client codes..."
echo "------------------------------------------------------"
rm -rf apps/child_chain_api
rm -rf apps/watcher_security_critical_api
rm -rf apps/watcher_info_api


echo "------------------------------------------------------"
echo "Generating childchain clients..."
echo "------------------------------------------------------"
docker run --rm \
    -v ${PWD}/apps:/apps \
    -v ${PWD}/../../apps/omg_child_chain_rpc/priv/swagger/:/swagger \
    --user $(id -u):$(id -g) \
    openapitools/openapi-generator-cli generate \
    -i /swagger/operator_api_specs.yaml \
    -g elixir \
    -o /apps/child_chain_api/

echo "------------------------------------------------------"
echo "Generating watcher security clients..."
echo "------------------------------------------------------"
docker run --rm \
    -v ${PWD}/apps:/apps \
    -v ${PWD}/../../apps/omg_watcher_rpc/priv/swagger/:/swagger \
    --user $(id -u):$(id -g) \
    openapitools/openapi-generator-cli generate \
    -i /swagger/security_critical_api_specs.yaml \
    -g elixir \
    -o /apps/watcher_security_critical_api/

echo "------------------------------------------------------"
echo "Generating watcher info clients..."
echo "------------------------------------------------------"
docker run --rm \
    -v ${PWD}/apps:/apps \
    -v ${PWD}/../../apps/omg_watcher_rpc/priv/swagger/:/swagger \
    --user $(id -u):$(id -g) \
    openapitools/openapi-generator-cli generate \
    -i /swagger/info_api_specs.yaml \
    -g elixir \
    -o /apps/watcher_info_api/

