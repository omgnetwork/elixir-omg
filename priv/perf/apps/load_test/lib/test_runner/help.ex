# Copyright 2019-2020 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule LoadTest.TestRunner.Help do
  @moduledoc """
  Shows help info for TestRunner.
  """

  require Logger

  @help """

  `LoadTest.TestRunner` accepts three required parameters:

  1. Test name (`transactions` or `deposits`)
  2. Rate in tests per second
  3. Period in seconds

  For example, if you want to run `deposits` with 5 tests / second rate over 20 seconds, you
  should run the following command:

  ```
   mix run -e "LoadTest.TestRunner.run()" -- deposits 5 20
  ```

  To modify tests values use `TEST_CONFIG_PATH`. It should contain a path to json file containing
  test values:

  ```
  TEST_CONFIG_PATH=./my_file mix run -e "LoadTest.TestRunner.run()" -- deposits 1 5
  ```

  To see which values can be overridden, use

  ```
  mix run -e "LoadTest.TestRunner.run()" -- help test_name
  ```

  To see env variable, use:

  ```
  mix run -e "LoadTest.TestRunner.run()" -- help env
  ```

  Additonal notes.

  These tests use datadog to collect metrics so you need to set:

  - STATIX_TAG - env tag used by statsd/datadog-agent. different test runs are distinguished by this tag in datadog dashboard
  - DD_API_KEY - datadog api key
  - DD_APP_KEY - datadog app key

  Available dashboards are:
  - https://app.datadoghq.com/dashboard/rpx-xu2-b2g/deposits-perf-tests - deposits tests
  - https://app.datadoghq.com/dashboard/7kh-xx4-9qu/transactions-perf-tests - transactions tests

  Since `LoadTest.Ethereum.NonceTracker` is used to track nonces for addresses in the Ethereum,
  it's not possible to run multiple instances of these tests using the same addresses. It may cause race conditions.


  Creating new tests.

  1. Create Chaperon runner (see `LoadTest.Runner.Transactions`)
  2. Create Chaperon scenario (see `LoadTest.Scenario.Transactions`)
  3. Wrap functions that you want to collect metrics for with `LoadTest.Service.Metrics.run_with_metrics/2`)
  4. Run tests so metrics are sent to Datadog
  5. Create dashboards and monitors in Datadog.
  """

  @help_test %{
    "deposits" => """

    A single iteration of this test consists of the following steps:

    1. It creates two accounts: the depositor and the receiver.
    2. It funds depositor with the specified amount (`initial_amount`) on the rootchain.
    3. It creates deposit (`deposited_amount`) with gas price `gas_price` for the depositor account on the childchain and
       checks balances on the rootchain and the childchain after this deposit.
    4. The depositor account sends the specifed amount (`transferred_amount`) on the childchain to the receiver
      and checks its balance on the childchain.

    Overridable parameters are:

    - token. default value is "0x0000000000000000000000000000000000000000"
    - initial_amount. default value is 500_000_000_000_000_000
    - deposited_amount default value is 200_000_000_000_000_000
    - transferred_amount. default value is 100_000_000_000_000_000
    - gas_price. default value is 2_000_000_000
    """,
    "transactions" => """

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

    Overridable parameters are:

    - initial_balance. default value is 760
    - token. default value is "0x0000000000000000000000000000000000000000"
    - fee. default value is 75
    """
  }

  @env """

  ETHEREUM_RPC_URL - Ethereum Json RPC url. Default value is http://localhost:8545
  RETRY_SLEEP - Sleeping period used when polling data. Default value is 1000 (ms)
  CHILD_CHAIN_URL - Childcahin url. Default value is http://localhost:9656
  WATCHER_SECURITY_URL - Watcher security url. Default value is http://localhost:7434
  WATCHER_INFO_URL - Watcehr info url. Default value is http://localhost:7534
  LOAD_TEST_FAUCET_PRIVATE_KEY - Faucet private key. Default value is 0xd885a307e35738f773d8c9c63c7a3f3977819274638d04aaf934a1e1158513ce
  CONTRACT_ADDRESS_ETH_VAULT - Eth vault contact address
  CONTRACT_ADDRESS_PAYMENT_EXIT_GAME - Payment exit game contract address
  CHILD_BLOCK_INTERVAL - Block generation interval. Default value is 1000 (ms)
  CONTRACT_ADDRESS_PLASMA_FRAMEWORK - Plasma framework contract address
  CONTRACT_ADDRESS_ERC20_VAULT - Erc 20 vault contract address
  FEE_AMOUNT - Fee amount used by faucet when funding accounts. Default value is 75
  DEPOSIT_FINALITY_MARGIN - Number of comfirmation for a deposit. Default value is 10
  """

  def help() do
    IO.puts(@help)
  end

  def help("env") do
    IO.puts(@env)
  end

  def help(test_name) do
    case @help_test[test_name] do
      nil ->
        tests =
          @help_test
          |> Map.keys()
          |> Enum.join(", ")

        IO.puts("""

        Documentation for `#{test_name}` is not found. Available tests are #{tests}.

        """)

      doc ->
        IO.puts(doc)
    end
  end
end
