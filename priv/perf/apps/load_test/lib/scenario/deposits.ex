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

defmodule LoadTest.Scenario.Deposits do
  use Chaperon.Scenario

  alias Chaperon.Session
  alias LoadTest.ChildChain.Deposit

  @spec run(Session.t()) :: Session.t()
  def run(session) do
    tps = config(session, [:run_config, :tps])
    period_in_seconds = config(session, [:run_config, :period_in_seconds])

    total_number_of_transactions = tps * period_in_seconds
    period_in_mseconds = period_in_seconds * 1_000

    session
    |> cc_spread(
      :create_deposit,
      total_number_of_transactions,
      period_in_mseconds
    )
    |> await_all(:create_deposit)
  end

  def create_deposit(session) do
    from_address = config(session, [:chain_config, :from_address])
    to_address = config(session, [:chain_config, :to_address])
    token = config(session, [:chain_config, :token])
    amount = config(session, [:chain_config, :amount])

    txhash = Deposit.deposit_from(from_address, amount, token, return: :txhash)

    # balance = Client.get_exact_balance(alice_account, expecting_amount)

    # {:ok, [sign_hash, typed_data, _txbytes]} =
    #   Client.create_transaction(
    #     Currency.to_wei(amount),
    #     alice_account,
    #     bob_account
    #   )

    # _ = Client.submit_transaction(typed_data, sign_hash, [alice_pkey, alice_pkey])
    session
  end
end
