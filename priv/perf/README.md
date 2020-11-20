# Perf

Umbrella app for performance/load/stress tests

## Tests with assertions

These tests check the integrity of the system during their run. They meant to be run with the given rate (tests/second) over the given period (seconds).

During test runs, the perf project sends metrics to datadog. After a test finishes its executions, datadog monitor events are checked. If some metrics exceed values set in monitors, the test is marked as failed.

Currently there two tests are implemented: `deposits` and `transactions` tests.

### Deposits tests

A single iteration of this test consists of the following steps:

1. It creates two accounts: the depositor and the receiver.
2. It funds depositor with the specified amount (`initial_amount`) on the rootchain.
3. It creates deposit (`deposited_amount`) with gas price `gas_price` for the depositor account on the childchain and
   checks balances on the rootchain and the childchain after this deposit.
4. The depositor account sends the specifed amount (`transferred_amount`) on the childchain to the receiver
  and checks its balance on the childchain.

### Transactions tests

A single iteration of this test consists of the following steps:

1.1 Two accounts are created - the sender and the receiver

2.1 The sender account is funded with `initial_amount` `token`
2.2 The balance on the childchain of the sender is validated using WatcherInfoAPI.Api.Account.account_get_balance API.
2.3 Utxos of the sender are validated using WatcherInfoAPI.Api.Account.account_get_utxos API

3.1 The sender sends all his tokens to the receiver with fee `fee`
3.2 The balance on the childchain of the sender is validated
3.3 The balance on the childchain of the receiver is validated
3.4 Utxos of the sender are validated
3.5 Utxos of the receiver are validated

### Basic usage

If you want to run `deposits` with 5 tests / second rate over 20 seconds, you
should run the following command:

```bash
 mix run -e "LoadTest.TestRunner.run()" -- deposits 5 20
```

### Help and documentation

To see up-to-date docs, run:

```bash
mix run -e "LoadTest.TestRunner.run()" -- help
```

To see info about a specific test, run:

```bash
 mix run -e "LoadTest.TestRunner.run()" -- help transactions
```

### Docker

The perf project is packaged into a docker image. So instead of using the project directly, you can run all commands with docker container.

For example, help command looks like this:

```bash
docker run -it omisego/perf:latest mix run -e "LoadTest.TestRunner.run()" -- help
```

To run deposits tests, use:

```bash
docker run -it --env-file ./localchain_contract_addresses.env --network host omisego/perf:latest mix run -e "LoadTest.TestRunner.run()" -- "deposits" 10 1
```

## Tests without assertions

### How to run the tests

#### 1. Set up the environment vars

```
export CHILD_CHAIN_URL=<childchain api url>
export WATCHER_INFO_URL=<watcher-info api url>
export ETHEREUM_RPC_URL=<ethereum node url>
export CONTRACT_ADDRESS_PLASMA_FRAMEWORK=<address of the plasma framework contract>
export CONTRACT_ADDRESS_ETH_VAULT=<address of the eth vault contract>
export CONTRACT_ADDRESS_ERC20_VAULT=<address of the erc20 vault contract>
export LOAD_TEST_FAUCET_PRIVATE_KEY=<faucet private key>
```


#### 2. Generate the open-api client
 ```
make init
```

#### 3. Configure the tests
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

#### 4. Run the tests
```
MIX_ENV=<your_env> mix test
```

Or just `mix test` if you want to run against local services.

You can specify a particular test on the command line e.g.

```
MIX_ENV=dev mix test apps/load_test/test/load_tests/runner/childchain_test.exs
```

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

### Retrying on errors
The Tesla HTTP middleware can be configured to retry on error.
By default this is disabled, but it can be enabled by modifying the `retry?` function in `connection_defaults.ex`.

For example, to retry any 500 response:
```
  defp retry?() do
    fn
      {:ok, %{status: status}} when status in 500..599 -> true
      {:ok, _} -> false
      {:error, _} -> false
    end
  end
```

See [Tesla.Middleware.Retry](https://hexdocs.pm/tesla/Tesla.Middleware.Retry.html) for more details.
