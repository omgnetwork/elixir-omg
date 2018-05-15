#!/bin/bash
cd ../..
echo -e "Script pid: $$\n\trun mix from: $PWD\n\twitch config: $@"
mix run --no-start -e 'OmiseGO.API.Application.init()' --config $@ 2>&1
#mix run --no-start -e 'OmiseGO.API.Commands.init()' --config $@ 2>&1
iex --sname main -S mix run --config $@ 2>&1
