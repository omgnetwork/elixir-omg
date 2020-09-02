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

  alias OMG.Crypto
  alias OMG.State.Transaction
  alias OMG.TypedDataHash
  alias OMG.WatcherInfo.DB
  alias OMG.WatcherInfo.UtxoSelection

  require Transaction.Payment

  @empty_metadata <<0::256>>
  @max_outputs Transaction.Payment.max_outputs()

  @type create_t() ::
          {:ok, nonempty_list(transaction_t())}
          | {:error, :too_many_inputs}
          | {:error, :too_many_outputs}
          | {:error, :empty_transaction}

  @type fee_t() :: %{
          currency: UtxoSelection.currency_t(),
          amount: non_neg_integer()
        }
  @type payment_t() :: %{
          owner: Crypto.address_t() | nil,
          currency: UtxoSelection.currency_t(),
          amount: pos_integer()
        }

  @type transaction_t() :: %{
          inputs: nonempty_list(%DB.TxOutput{}),
          outputs: nonempty_list(payment_t()),
          fee: fee_t(),
          txbytes: Transaction.tx_bytes() | nil,
          metadata: Transaction.metadata(),
          sign_hash: Crypto.hash_t() | nil,
          typed_data: TypedDataHash.Types.typedDataSignRequest_t()
        }

  @type order_t() :: %{
          owner: Crypto.address_t(),
          payments: list(payment_t()),
          metadata: binary() | nil,
          fee: fee_t()
        }

  @type utxos_map_t() :: %{UtxoSelection.currency_t() => UtxoSelection.utxo_list_t()}
  @type inputs_t() :: {:ok, utxos_map_t()} | {:error, {:insufficient_funds, list(map())}} | {:error, :too_many_inputs}

  @doc """
  Given an `order`, finds spender's inputs sufficient to perform a payment.
  If also provided with receiver's address, creates and encodes a transaction.
  """
  @spec select_inputs(utxos_map_t(), order_t()) :: inputs_t()
  def select_inputs(utxos, %{payments: payments, fee: fee}) do
    token_utxo_selection =
      payments
      |> UtxoSelection.needed_funds(fee)
      |> UtxoSelection.select_utxo(utxos)

    case UtxoSelection.funds_sufficient(token_utxo_selection) do
      {:ok, funds} ->
        stealth_merge_utxos =
          utxos
          |> UtxoSelection.prioritize_merge_utxos(funds)
          |> UtxoSelection.add_utxos_for_stealth_merge(funds)

        {:ok, stealth_merge_utxos}

      err ->
        err
    end
  end

  @doc """
  Given selected utxos and order, create inputs and outputs, then returns either {:error, reason} or transactions.

  - Returns transactions when the inputs look good.
  - Returns an error when any of the following conditions is met:
    1. A number of outputs overs maximum.
    2. An inputs are empty.
  """
  @spec create(utxos_map_t(), order_t()) :: create_t()
  def create(utxos_per_token, order) do
    inputs = build_inputs(utxos_per_token)
    outputs = build_outputs(utxos_per_token, order)

    cond do
      Enum.count(outputs) > @max_outputs ->
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
             sign_hash: TypedDataHash.hash_struct(raw_tx)
           }
         ]}
    end
  end

  @spec include_typed_data(UtxoSelection.advice_t()) :: UtxoSelection.advice_t()
  def include_typed_data({:error, _} = err), do: err

  def include_typed_data({:ok, txs}),
    do: {
      :ok,
      %{transactions: Enum.map(txs, fn tx -> Map.put_new(tx, :typed_data, add_type_specs(tx)) end)}
    }

  def generate_merge_transactions(merge_inputs) do
    merge_inputs
    |> Stream.chunk_every(@max_outputs)
    |> Enum.flat_map(fn input_set ->
      case input_set do
        [_single_input] ->
          []

        inputs ->
          {:ok, transaction} = create_merge(inputs)
          transaction
      end
    end)
  end

  defp create_merge(inputs) do
    %{currency: currency, owner: owner} = List.first(inputs)

    create([{currency, inputs}], %{
      fee: %{amount: 0, currency: currency},
      metadata: @empty_metadata,
      owner: owner,
      payments: []
    })
  end

  defp build_inputs(utxos_per_token) do
    utxos_per_token
    |> Enum.map(fn {_, utxos} -> utxos end)
    |> List.flatten()
  end

  defp build_outputs(utxos_per_token, order) do
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

  defp add_type_specs(%{inputs: inputs, outputs: outputs, metadata: metadata}) do
    message =
      [
        create_inputs(inputs),
        create_outputs(outputs),
        [metadata: metadata || @empty_metadata]
      ]
      |> Enum.concat()
      |> Map.new()

    %{
      domain: TypedDataHash.Config.domain_data_from_config(),
      message: message
    }
    |> Map.merge(TypedDataHash.Types.eip712_types_specification())
  end

  defp create_inputs(inputs) do
    inputs
    |> Stream.map(fn input -> %{blknum: input.blknum, txindex: input.txindex, oindex: input.oindex} end)
    |> Stream.concat(Stream.repeatedly(fn -> %{blknum: 0, txindex: 0, oindex: 0} end))
    |> (fn input -> Enum.zip([:input0, :input1, :input2, :input3], input) end).()
  end

  defp create_outputs(outputs) do
    zero_addr = OMG.Eth.zero_address()
    empty_gen = fn -> %{owner: zero_addr, currency: zero_addr, amount: 0} end

    outputs
    |> Stream.concat(Stream.repeatedly(empty_gen))
    |> (fn output -> Enum.zip([:output0, :output1, :output2, :output3], output) end).()
  end
end
