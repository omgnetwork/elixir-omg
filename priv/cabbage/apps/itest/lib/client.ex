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
defmodule Itest.Client do
  @moduledoc """
    An interface to Watcher API.
  """
  alias Itest.Transactions.Currency
  alias Itest.Transactions.Deposit
  alias Itest.Transactions.Encoding
  alias WatcherInfoAPI.Api.Account
  alias WatcherInfoAPI.Api.Fees
  alias WatcherInfoAPI.Api.Transaction
  alias WatcherInfoAPI.Connection, as: WatcherInfo
  alias WatcherInfoAPI.Model.AddressBodySchema1
  alias WatcherInfoAPI.Model.CreateTransactionsBodySchema
  alias WatcherInfoAPI.Model.TransactionCreateFee
  alias WatcherInfoAPI.Model.TransactionCreatePayments

  import Itest.Poller, only: [wait_on_receipt_confirmed: 1, submit_typed: 1]

  require Logger

  @gas 180_000

  def deposit(amount_in_wei, output_address, vault_address, currency \\ Currency.ether()) do
    deposit_transaction = deposit_transaction(amount_in_wei, output_address, currency)

    data = ABI.encode("deposit(bytes)", [deposit_transaction])

    txmap = %{
      from: output_address,
      to: vault_address,
      value: Encoding.to_hex(amount_in_wei),
      data: Encoding.to_hex(data),
      gas: Encoding.to_hex(@gas)
    }

    {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap)

    wait_on_receipt_confirmed(receipt_hash)
    {:ok, receipt_hash}
  end

  def create_transaction(amount_in_wei, input_address, output_address, currency \\ Currency.ether()) do
    transaction = %CreateTransactionsBodySchema{
      owner: input_address,
      payments: [
        %TransactionCreatePayments{
          amount: amount_in_wei,
          currency: Encoding.to_hex(currency),
          owner: output_address
        }
      ],
      fee: %TransactionCreateFee{currency: Encoding.to_hex(currency)}
    }

    {:ok, response} = Transaction.create_transaction(WatcherInfo.new(), transaction)

    %{
      "result" => "complete",
      "transactions" => [
        %{
          "sign_hash" => sign_hash,
          "typed_data" => typed_data,
          "txbytes" => txbytes
        }
      ]
    } = Jason.decode!(response.body)["data"]

    {:ok, [sign_hash, typed_data, txbytes]}
  end

  def submit_transaction(typed_data, sign_hash, private_keys) do
    signatures =
      Enum.map(private_keys, fn private_key ->
        sign_hash
        |> Encoding.to_binary()
        |> Encoding.signature_digest(private_key)
        |> Encoding.to_hex()
      end)

    typed_data_signed = Map.put_new(typed_data, "signatures", signatures)

    submit_typed(typed_data_signed)
  end

  def get_utxos(params) do
    default_paging = %{page: 1, limit: 200}
    %{address: address, page: page, limit: limit} = Map.merge(default_paging, params)

    {:ok, response} =
      Account.account_get_utxos(WatcherInfo.new(), %AddressBodySchema1{address: address, page: page, limit: limit})

    data = Jason.decode!(response.body)
    {:ok, data}
  end

  def get_gas_used(receipt_hash), do: Itest.Gas.get_gas_used(receipt_hash)

  def get_balance(address), do: Itest.Poller.get_balance(address)
  def get_balance(address, amount), do: Itest.Poller.pull_balance_until_amount(address, amount)

  def get_fees() do
    {:ok, response} = Fees.fees_all(WatcherInfo.new())
    {:ok, Jason.decode!(response.body)["data"]}
  end

  defp deposit_transaction(amount_in_wei, address, currency) do
    address
    |> Deposit.new(currency, amount_in_wei)
    |> Encoding.get_data_for_rlp()
    |> ExRLP.encode()
  end
end
