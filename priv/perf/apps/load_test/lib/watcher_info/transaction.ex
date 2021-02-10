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

defmodule LoadTest.WatcherInfo.Transaction do
  @moduledoc """
    Functions for working with transactions WatherInfo API
  """

  alias ExPlasma.Encoding
  alias LoadTest.Ethereum.Account
  alias LoadTest.Service.Metrics
  alias LoadTest.Service.Sync

  @poll_timeout 60_000

  @spec create_transaction(
          non_neg_integer(),
          Account.addr_t(),
          Account.addr_t(),
          Account.addr_t(),
          non_neg_integer()
        ) ::
          {:ok, [binary()]} | {:error, map()}

  def create_transaction(amount_in_wei, input_address, output_address, currency \\ <<0::160>>, timeout \\ 120_000) do
    func = fn ->
      Metrics.run_with_metrics(
        fn -> do_create_transaction(amount_in_wei, input_address, output_address, currency) end,
        "WatcherInfo.create_transaction"
      )
    end

    Sync.repeat_until_success(func, timeout, "Failed to create a transaction")
  end

  @spec submit_transaction(binary(), binary(), [binary()]) :: map()
  def submit_transaction(typed_data, sign_hash, private_keys) do
    signatures =
      Enum.map(private_keys, fn private_key ->
        sign_hash
        |> to_binary()
        |> signature_digest(private_key)
        |> Encoding.to_hex()
      end)

    typed_data_signed = Map.put_new(typed_data, "signatures", signatures)

    Sync.repeat_until_success(
      fn ->
        Metrics.run_with_metrics(
          fn -> submit_typed(typed_data_signed) end,
          "WatcherInfo.submit_typed"
        )
      end,
      @poll_timeout,
      "Failed to submit transaction"
    )
  end

  defp do_create_transaction(amount_in_wei, input_address, output_address, currency) do
    transaction = %WatcherInfoAPI.Model.CreateTransactionsBodySchema{
      owner: Encoding.to_hex(input_address),
      payments: [
        %WatcherInfoAPI.Model.TransactionCreatePayments{
          amount: amount_in_wei,
          currency: Encoding.to_hex(currency),
          owner: Encoding.to_hex(output_address)
        }
      ],
      fee: %WatcherInfoAPI.Model.TransactionCreateFee{currency: Encoding.to_hex(currency)}
    }

    {:ok, response} =
      WatcherInfoAPI.Api.Transaction.create_transaction(LoadTest.Connection.WatcherInfo.client(), transaction)

    result = Jason.decode!(response.body)["data"]

    process_transaction_result(result)
  end

  defp submit_typed(typed_data_signed) do
    {:ok, response} = execute_submit_typed(typed_data_signed)
    decoded_response = Jason.decode!(response.body)["data"]

    case decoded_response do
      %{"messages" => %{"code" => "submit:utxo_not_found"}} ->
        {:error, :data_not_found}

      %{"messages" => %{"code" => "operation:service_unavailable"}} = error ->
        {:error, error}

      %{"tx_hash" => _} ->
        {:ok, decoded_response}
    end
  end

  defp execute_submit_typed(typed_data_signed) do
    WatcherInfoAPI.Api.Transaction.submit_typed(LoadTest.Connection.WatcherInfo.client(), typed_data_signed)
  end

  defp process_transaction_result(result) do
    case result do
      %{"code" => "create:client_error"} ->
        {:error, result}

      %{
        "result" => "complete",
        "transactions" => [
          %{
            "sign_hash" => sign_hash,
            "typed_data" => typed_data,
            "txbytes" => txbytes
          }
        ]
      } ->
        {:ok, [sign_hash, typed_data, txbytes]}

      error ->
        {:error, error}
    end
  end

  defp signature_digest(hash_digest, private_key) do
    {:ok, {<<r::size(256), s::size(256)>>, recovery_id}} = ExSecp256k1.sign_compact(hash_digest, private_key)

    # EIP-155
    # See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-155.md
    base_recovery_id = 27
    recovery_id = base_recovery_id + recovery_id

    <<r::integer-size(256), s::integer-size(256), recovery_id::integer-size(8)>>
  end

  defp to_binary(hex) do
    hex
    |> String.replace_prefix("0x", "")
    |> String.upcase()
    |> Base.decode16!()
  end
end
