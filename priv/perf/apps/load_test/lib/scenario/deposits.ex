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
  @moduledoc """
  The scenario for deposits tests:

  1. It creates two accounts: the depositor and the receiver.
  2. It funds depositor with the specified amount on the rootchain.
  3. It creates deposit for the depositor account on the childchain and
     checks balances on the rootchain and the childchain after this deposit.
  4. The depositor account sends the specifed amount on the childchain to the receiver
     and checks its balance on the childchain.

  """

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
      :create_deposit_and_make_assertions,
      total_number_of_transactions,
      period_in_mseconds
    )
    |> await_all(:create_deposit_and_make_assertions)
  end

  def create_deposit_and_make_assertions(session) do
    with {:ok, from, to} <- create_accounts(session),
         :ok <- create_deposit(from, session),
         :ok <- send_value_to_receiver(from, to, session) do
      Session.add_metric(session, "error_rate", 0)
    else
      error ->
        log_error(session, "#{__MODULE__} failed with #{inspect(error)}")

        session
        |> Session.add_metric("error_rate", 1)
        |> Session.add_error(:test, error)
    end
  end

  defp create_accounts(session) do
    initial_amount = config(session, [:chain_config, :initial_amount])
    {:ok, from_address} = Account.new()
    {:ok, to_address} = Account.new()

    {:ok, _} = Faucet.fund_root_chain_account(from_address.addr, initial_amount)

    {:ok, from_address, to_address}
  end

  defp create_deposit(from_address, session) do
    token = config(session, [:chain_config, :token])
    deposited_amount = config(session, [:chain_config, :deposited_amount])
    initial_amount = config(session, [:chain_config, :initial_amount])

    txhash = Deposit.deposit_from(from_address, deposited_amount, token, 10, 0, :txhash)

    gas_used = Ethereum.get_gas_used(txhash)

    with :ok <-
           fetch_childchain_balance(from_address,
             amount: deposited_amount,
             token: token,
             error: :wrong_childchain_from_balance_after_deposit
           ),
         :ok <-
           fetch_rootchain_balance(
             from_address,
             amount: initial_amount - deposited_amount - gas_used,
             token: token,
             error: :wrong_rootchain_balance_after_deposit
           ) do
      :ok
    else
      error ->
        error
    end
  end

  defp send_value_to_receiver(from_address, to_address, session) do
    token = config(session, [:chain_config, :token])
    transferred_amount = config(session, [:chain_config, :transferred_amount])

    with _ <- send_amount_on_childchain(from_address, to_address, token, transferred_amount),
         :ok <-
           fetch_childchain_balance(
             to_address,
             amount: transferred_amount,
             token: token,
             error: :wrong_childchain_to_balance_after_sending_deposit
           ) do
      :ok
    else
      error -> error
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

   Ethereum.submit_transaction(typed_data, sign_hash, [from.priv])
  end

  defp fetch_childchain_balance(account, amount: amount, token: token, error: error) do
    childchain_balance = Ethereum.fetch_balance(account.addr, amount, token)

    case childchain_balance["amount"] do
      ^amount -> :ok
      _ -> error
    end
  end

  defp fetch_rootchain_balance(account, amount: amount, token: token, error: error) do
    rootchain_balance = Ethereum.fetch_rootchain_balance(account.addr, token)

    case rootchain_balance do
      ^amount -> :ok
      _ -> error
    end
  end
end
