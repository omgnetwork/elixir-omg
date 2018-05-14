#!/usr/bin/env bash
geth --dev --dev.period 2 --rpc --rpcapi personal,web3,eth &
GETH_PID=$!
sleep 3
mix run --no-start -e 'OmiseGO.Eth.DevHelpers.prepare_test_env()'
cd apps/omisego_db; mix run init_db.exs
cd ../../apps/omisego_watcher
mix test --only watcher_tests
RESULT=$?
kill -9 $GETH_PID
exit $RESULT

