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

defmodule OMG.WatcherInfo.Transaction do
  @moduledoc """
  Module create transaction from selected utxos and order.
  """

  alias OMG.State.Transaction
  alias OMG.TypedDataHash
  alias OMG.WatcherInfo.DB

  require Transaction.Payment

  @empty_metadata <<0::256>>

  @type create_t() ::
          {:ok, nonempty_list(transaction_t())}
          | {:error, :too_many_inputs}
          | {:error, :too_many_outputs}
          | {:error, :empty_transaction}

  @type transaction_t() :: %{
          inputs: nonempty_list(%DB.TxOutput{}),
          outputs: nonempty_list(UtxoSelection.payment_t()),
          fee: UtxoSelection.fee_t(),
          txbytes: Transaction.tx_bytes() | nil,
          metadata: Transaction.metadata(),
          sign_hash: Crypto.hash_t() | nil,
          typed_data: TypedDataHash.Types.typedDataSignRequest_t()
        }

  @type order_t() :: %{
          owner: Crypto.address_t(),
          payments: nonempty_list(UtxoSelection.payment_t()),
          metadata: binary() | nil,
          fee: UtxoSelection.fee_t()
        }

  @type utxos_map_t() :: %{UtxoSelection.currency_t() => UtxoSelection.utxo_list_t()}

  @doc """
  Given selected utxos and order, create inputs and outputs, then returns a transaction.

  Returns an error when any of the following conditions is met:

  1. A number of outputs overs maximum.
  2. A number of inputs overs maximum.
  3. An inputs are empty.
  """
  @spec create(utxos_map_t(), order_t()) :: create_t()
  def create(utxos_per_token, order) do
    inputs = create_input(utxos_per_token)
    outputs = create_output(utxos_per_token, order)

    cond do
      Enum.count(inputs) > Transaction.Payment.max_inputs() ->
        {:error, :too_many_inputs}

      Enum.count(outputs) > Transaction.Payment.max_outputs() ->
        {:error, :too_many_outputs}

      Enum.empty?(inputs) ->
        {:error, :empty_transaction}

      true ->
        raw_tx = create_raw_transaction(inputs, outputs, order.metadata)

        {:ok,
         [
           %{
             inputs: inputs,
             outputs: outputs,
             fee: order.fee,
             metadata: order.metadata,
             txbytes: Transaction.raw_txbytes(raw_tx),
             sign_hash: TypedDataHash.hash_struct(raw_tx),
           }
         ]}
    end
  end

  defp create_input(utxos_per_token) do
    utxos_per_token
    |> Enum.map(fn {_, utxos} -> utxos end)
    |> List.flatten()
  end

  defp create_output(utxos_per_token, order) do
    rests =
      utxos_per_token
      |> Stream.map(fn {token, utxos} ->
        outputs =
          [order.fee | order.payments]
          |> Stream.filter(fn %{currency: currency} -> currency == token end)
          |> Stream.map(fn %{amount: amount} -> amount end)
          |> Enum.sum()

        inputs = utxos |> Stream.map(fn %{amount: amount} -> amount end) |> Enum.sum()
        %{amount: inputs - outputs, owner: order.owner, currency: token}
      end)
      |> Enum.filter(fn %{amount: amount} -> amount > 0 end)

    order.payments ++ rests
  end

  defp create_raw_transaction(inputs, outputs, metadata) do
    Transaction.Payment.new(
      Enum.map(inputs, fn input -> {input.blknum, input.txindex, input.oindex} end),
      Enum.map(outputs, fn output -> {output.owner, output.currency, output.amount} end),
      metadata || @empty_metadata
    )
  end
end
