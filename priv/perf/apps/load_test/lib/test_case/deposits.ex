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

defmodule LoadTest.TestCase.Deposits do
  alias LoadTest.ChildChain.Deposit
  alias LoadTest.Ethereum
  alias LoadTest.Ethereum.Account
  alias LoadTest.Service.Faucet
  alias LoadTest.TestCase

  @behaviour TestCase

  @impl TestCase
  def run(params) do
    create_deposit(params)
  rescue
    _error ->
      %{state: :error, type: :runtime_error}
  end

  defp create_deposit(params) do
    token = Keyword.fetch!(params, :token)
    amount = Keyword.fetch!(params, :amount)
    initial_balance = 3 * amount

    {:ok, from_address} = Account.new()
    {:ok, to_address} = Account.new()
    {:ok, _} = Faucet.fund_root_chain_account(from_address.addr, initial_balance)

    txhash =
      Deposit.deposit_from(from_address, 2 * amount, token, return: :txhash, deposit_finality_margin: 10, gas_price: 0)

    gas_used = Ethereum.get_gas_used(txhash)

    with :ok <-
           fetch_childchain_balance(from_address, 2 * amount, token, :wrong_childchain_from_balance_after_deposit),
         :ok <-
           fetch_rootchain_balance(
             from_address,
             initial_balance - 2 * amount - gas_used,
             token,
             :wrong_rootchain_balance_after_deposit
           ),
         _ <- send_amount_on_childchain(from_address, to_address, token, amount),
         :ok <- fetch_childchain_balance(to_address, amount, token, :wrong_childchain_to_balance_after_sending_deposit) do
      %{status: :ok}
    else
      error ->
        %{status: :error, type: error}
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

    _ = Ethereum.submit_transaction(typed_data, sign_hash, [from.priv])
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
