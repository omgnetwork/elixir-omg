#!/bin/bash
#starts child chanin with defined config (use in TrackerOmisego.Fixtures)

cd ../..
echo -e "Script pid: $$\n\trun mix from: $PWD\n\twith config: $@"
#do not run iex in the background, the parent process may want kill all child and this process
iex --sname main -S mix run --config $@ 2>&1
