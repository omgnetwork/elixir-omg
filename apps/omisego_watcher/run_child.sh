#!/bin/bash
cd ../..
echo -e "Script pid: $$\n\trun mix from: $PWD\n\twitch config: $@"
mix run --no-start -e 'OmiseGO.DB.init()' --config $@ 2>&1
iex --sname main -S mix run  --no-start --config $@ -e "Application.ensure_all_started(:omisego_jsonrpc)" 2>&1
