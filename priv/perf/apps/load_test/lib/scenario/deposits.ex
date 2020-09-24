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
  alias LoadTest.Ethereum
  alias LoadTest.Ethereum.Account

  alias LoadTest.Service.Faucet

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
    token = config(session, [:chain_config, :token])
    amount = config(session, [:chain_config, :amount])
    initial_balance = amount + 500_000_000_000

    {:ok, from_address} = Account.new()
    {:ok, to_address} = Account.new()
    {:ok, _} = Faucet.fund_root_chain_account(from_address.addr, initial_balance)

    txhash = Deposit.deposit_from(from_address, amount, token, return: :txhash, deposit_finality_margin: 10)
    gas_used = Ethereum.get_gas_used(txhash)

    with :ok <-
           fetch_childchain_balance(from_address, amount, token, :wrong_childchain_from_balance_after_deposit),
         :ok <-
           fetch_rootchain_balance(
             from_address,
             initial_balance - amount - gas_used,
             token,
             :wrong_rootchain_balance_after_deposit
           ),
         _ <- send_amount_on_childchain(from_address, to_address, token, amount),
         :ok <- fetch_childchain_balance(from_address, 0, token, :wrong_childchain_from_balance_after_sending_deposit),
         :ok <- fetch_childchain_balance(to_address, amount, token, :wrong_childchain_to_balance_after_sending_deposit) do
      session
    else
      error ->
        Session.abort(session, error)
    end
  end

  defp send_amount_on_childchain(from, to, token, amount) do
    {:ok, [sign_hash, typed_data, _txbytes]} =
      Ethereum.create_transaction(
        amount,
        from.addr,
        to.addr,
        token
      )

    # from account needs to sign 2 inputs of 1 Eth, 1 for Bob and 1 for the fees
    _ = Ethereum.submit_transaction(typed_data, sign_hash, [from.priv, to.priv])
  end

  defp fetch_childchain_balance(account, amount, token, error) do
    childchain_balance = Ethereum.fetch_balance(account.addr, amount, token)

    case childchain_balance["amount"] do
      ^amount -> :ok
      _ -> error
    end
  end

  defp fetch_rootchain_balance(account, amount, token, error) do
    rootchain_balance = Ethereum.fetch_rootchain_balance(account.addr, token)

    case rootchain_balance do
      ^amount -> :ok
      _ -> error
    end
  end
end
