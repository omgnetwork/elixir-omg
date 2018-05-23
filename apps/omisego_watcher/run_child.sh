#!/bin/bash
cd ../..
echo -e "Script pid: $$\n\trun mix from: $PWD\n\twitch config: $@"
mix run --no-start -e 'OmiseGO.DB.init()' --config $@ 2>&1
# FIXME I wish we could start just one app here, but in test env jsonrpc doesn't depend on api :(
mix run  --no-start --no-halt --config $@ -e "IO.inspect Application.ensure_all_started(:omisego_api); IO.inspect Application.ensure_all_started(:omisego_jsonrpc)" 2>&1
