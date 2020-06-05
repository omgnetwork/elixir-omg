# Perf

Umbrella app for performance/load/stress tests

## How to run the tests

### 1. Set up the environment vars

```
export CHILD_CHAIN_URL=<childchain api url>
export WATCHER_INFO_URL=<watcher-info api url>
export ETHEREUM_RPC_URL=<ethereum node url>
export CONTRACT_ADDRESS_PLASMA_FRAMEWORK=<address of the plasma framework contract>
export CONTRACT_ADDRESS_ETH_VAULT=<address of the eth vault contract>
export CONTRACT_ADDRESS_ERC20_VAULT=<address of the erc20 vault contract>
export LOAD_TEST_FAUCET_PRIVATE_KEY=<faucet private key>
```


### 2. Generate the open-api client
 ```
make init
```
(You need to run this any time you change the env vars above)

### 3. Configure the tests
Edit the config file (e.g. `config/dev.exs`) set the test parameters e.g.
```
  childchain_transactions_test_config: %{
    concurrent_sessions: 100,
    transactions_per_session: 600,
    transaction_delay: 1000
  }
```

Note that by default the tests use ETH both as the currency spent and as the fee. 
This makes the code simpler as it doesn't have to manage separate fee utxos. 
However, if necessary you can configure the tests to use a different currency. e.g.
```
config :load_test,
  test_currency: "0x942f123b3587EDe66193aa52CF2bF9264C564F87",
  fee_amount: 6_000_000_000_000_000,
```

### 4. Run the test
`MIX_ENV=dev mix test apps/load_test/test/load_tests/runner/childchain_test.exs`

**Important** After each test run, you need to wait ~15 seconds before running it again. 
This is necessary to wait for the faucet account's utxos to be spendable. 
Depending on the watcher-info load, it can take longer than this.

If you get an error like this
```
module=LoadTest.Service.Faucet Funding user 0x76f0a3aade31c19d306bc91b46817b95072a8cbd with 2 from utxo: 10800070000⋅
module=LoadTest.ChildChain.Transaction Transaction submission has failed, reason: "submit:utxo_not_found"⋅
```

then you haven't waited long enough.
Kill it, wait some more, try again.

### Increase connection pool size and connection
One can override the setup in config to increase the `pool_size` and `max_connection`. 
If you found the latency on the api calls are high but the data dog latency shows way smaller, 
it might be latency from setting up the connection instead of real api latency.
