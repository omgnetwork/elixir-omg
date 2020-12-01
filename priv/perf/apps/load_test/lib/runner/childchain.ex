# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule LoadTest.Runner.ChildChainTransactions do
  @moduledoc """
  Creates load on the child chain by submitting transactions as fast as possible.

  Run with `mix test apps/load_test/test/load_tests/runner/childchain_test.exs`

  In each session, the test creates a new address and funds it from the faucet.
  It then creates transactions from this address to another temporary address.
  Transactions are chained i.e. using the returned blocknum and tx_pos from `transaction.submit`
  we can calculate the next utxo to be spent without waiting for the block to finalize.
  This allows us to submit transactions as fast as possible, limited only by latency of `transaction.submit`

  Note that the latency of `transaction.submit` can be high enough to mean that one account sending
  transactions in this way is not enough to stress the childchain. It is necessary to run many concurrent
  sessions to provide meaningful load.
  """
  use Chaperon.LoadTest

  alias LoadTest.Ethereum.Account

  @default_config %{
    concurrent_sessions: 1,
    transactions_per_session: 1,
    transaction_delay: 0
  }

  def default_config() do
    Application.get_env(:load_test, :childchain_transactions_test_config, @default_config)
  end

  def scenarios() do
    test_currency = Application.fetch_env!(:load_test, :test_currency)
    fee_amount = Application.fetch_env!(:load_test, :fee_amount)
    config = default_config()

    {:ok, sender} = Account.new()
    {:ok, receiver} = Account.new()

    amount = 1

    ntx_to_send = config.transactions_per_session
    initial_funds = (amount + fee_amount) * ntx_to_send

    [
      {{config.concurrent_sessions, [LoadTest.Scenario.FundAccount, LoadTest.Scenario.SpendEthUtxo]},
       %{
         account: sender,
         initial_funds: initial_funds,
         sender: sender,
         receiver: receiver,
         amount: amount,
         test_currency: test_currency
       }}
    ]
  end
end
