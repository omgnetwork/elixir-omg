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

defmodule OMG.WatcherInfo.UtxoSelection do
  @moduledoc """
  Provides Utxos selection and merging algorithms.
  """

  alias OMG.Crypto
  alias OMG.State.Transaction
  alias OMG.TypedDataHash
  alias OMG.WatcherInfo.DB

  require Logger
  require Transaction
  require Transaction.Payment

  @type payment_t() :: %{
          owner: Crypto.address_t() | nil,
          currency: Transaction.Payment.currency(),
          amount: pos_integer()
        }

  @type fee_t() :: %{
          currency: Transaction.Payment.currency(),
          amount: non_neg_integer()
        }

  @type order_t() :: %{
          tx_type: non_neg_integer(),
          owner: Crypto.address_t(),
          payments: nonempty_list(payment_t()),
          fee: fee_t(),
          metadata: binary() | nil
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

  @type advice_t() ::
          {:ok,
           %{
             result: :complete | :intermediate,
             transactions: nonempty_list(transaction_t())
           }}
          | {:error, {:insufficient_funds, list(map())}}
          | {:error, :too_many_outputs}
          | {:error, :empty_transaction}

  @empty_metadata <<0::256>>

  @doc """
  Given order finds spender's inputs sufficient to perform a payment.
  If also provided with receiver's address, creates and encodes a transaction.
  TODO: seems unocovered by any tests
  """
  @spec create_advice(%{Transaction.Payment.currency() => list(%DB.TxOutput{})}, order_t()) :: advice_t()
  def create_advice(utxos, order) do
    %{tx_type: tx_type, owner: owner, payments: payments, fee: fee} = order
    needed_funds = needed_funds(payments, fee)
    token_utxo_selection = select_utxo(utxos, needed_funds)

    with {:ok, funds} <- funds_sufficient?(token_utxo_selection) do
      utxo_count =
        funds
        |> Stream.map(fn {_, utxos} -> length(utxos) end)
        |> Enum.sum()

      if utxo_count <= Transaction.Payment.max_inputs(),
        do: create_transaction(funds, order) |> respond(:complete),
        else: create_merge(tx_type, owner, funds) |> respond(:intermediate)
    end
  end

  # Given available Utxo set and needed amount, we try to find an Utxo which fully satisfies the payment (without
  # the change). If this fails, we start to collect Utxos (starting from largest amount) which will cover the payment.
  # We return {token, {change, [utxos for payment]}}, change > 0 means insufficient funds.
  # NOTE: order of Utxo list is implicitly assumed for the algorithm to work deterministically,
  # see: `OMG.WatcherInfo.DB.TxOutput.get_sorted_grouped_utxos`
  @spec select_utxo(%{Transaction.Payment.currency() => list(%DB.TxOutput{})}, %{
          Transaction.Payment.currency() => pos_integer()
        }) ::
          list({Transaction.Payment.currency(), {integer, list(%DB.TxOutput{})}})
  defp select_utxo(utxos, needed_funds) do
    Enum.map(needed_funds, fn {token, need} ->
      token_utxos = Map.get(utxos, token, [])

      {token,
       case Enum.find(token_utxos, fn %DB.TxOutput{amount: amount} -> amount == need end) do
         nil ->
           Enum.reduce_while(token_utxos, {need, []}, fn
             _, {need, acc} when need <= 0 -> {:halt, {need, acc}}
             %DB.TxOutput{amount: amount} = utxo, {need, acc} -> {:cont, {need - amount, [utxo | acc]}}
           end)

         utxo ->
           {0, [utxo]}
       end}
    end)
  end

  # Sums up payments by token. Fee is included.
  defp needed_funds(payments, %{currency: fee_currency, amount: fee_amount}) do
    needed_funds =
      payments
      |> Enum.group_by(& &1.currency)
      |> Stream.map(fn {token, payment} ->
        {token, payment |> Stream.map(& &1.amount) |> Enum.sum()}
      end)
      |> Map.new()

    Map.update(needed_funds, fee_currency, fee_amount, &(&1 + fee_amount))
  end

  # See also comment to `select_utxo` function
  defp funds_sufficient?(utxo_selection) do
    missing_funds =
      utxo_selection
      |> Stream.filter(fn {_, {missing, _}} -> missing > 0 end)
      |> Enum.map(fn {token, {missing, _}} -> %{token: OMG.Utils.HttpRPC.Encoding.to_hex(token), missing: missing} end)

    if Enum.empty?(missing_funds),
      do: {:ok, utxo_selection |> Enum.map(fn {token, {_, utxos}} -> {token, utxos} end)},
      else: {:error, {:insufficient_funds, missing_funds}}
  end

  defp create_transaction(utxos_per_token, order) do
    %{tx_type: tx_type, owner: owner, payments: payments, metadata: metadata, fee: fee} = order

    rests =
      utxos_per_token
      |> Stream.map(fn {token, utxos} ->
        outputs = [fee | payments] |> Stream.filter(&(&1.currency == token)) |> Stream.map(& &1.amount) |> Enum.sum()

        inputs = utxos |> Stream.map(& &1.amount) |> Enum.sum()
        %{amount: inputs - outputs, owner: owner, currency: token}
      end)
      |> Enum.filter(&(&1.amount > 0))

    outputs = payments ++ rests

    inputs =
      utxos_per_token
      |> Enum.map(fn {_, utxos} -> utxos end)
      |> List.flatten()

    cond do
      Enum.count(outputs) > Transaction.Payment.max_outputs() ->
        {:error, :too_many_outputs}

      Enum.empty?(inputs) ->
        {:error, :empty_transaction}

      true ->
        raw_tx = create_raw_transaction(tx_type, inputs, outputs, metadata)

        {:ok,
         %{
           tx_type: tx_type,
           inputs: inputs,
           outputs: outputs,
           fee: fee,
           metadata: metadata,
           txbytes: create_txbytes(raw_tx),
           sign_hash: compute_sign_hash(raw_tx)
         }}
    end
  end

  defp create_merge(tx_type, owner, utxos_per_token) do
    utxos_per_token
    |> Enum.map(fn {token, utxos} ->
      Stream.chunk_every(utxos, Transaction.Payment.max_outputs())
      |> Enum.map(fn
        [_single_input] ->
          # merge not needed
          []

        inputs ->
          create_transaction([{token, inputs}], %{
            tx_type: tx_type,
            fee: %{amount: 0, currency: token},
            metadata: @empty_metadata,
            owner: owner,
            payments: []
          })
      end)
    end)
    |> List.flatten()
    |> Enum.map(fn {:ok, tx} -> tx end)
  end

  defp create_raw_transaction(tx_type, inputs, outputs, metadata) do
    # Somehow the API is designed to return nil txbytes instead of claiming that as bad request :(
    # So we need to return nil here
    # See the test: "test /transaction.create does not return txbytes when spend owner is not provided"
    case Enum.any?(outputs, &(&1.owner == nil)) do
      true ->
        nil

      false ->
        Transaction.Payment.Builder.new_payment(
          tx_type,
          inputs |> Enum.map(&{&1.blknum, &1.txindex, &1.oindex}),
          outputs |> Enum.map(&{&1.owner, &1.currency, &1.amount}),
          metadata || @empty_metadata
        )
    end
  end

  defp create_txbytes(tx) do
    with tx when not is_nil(tx) <- tx,
         do: Transaction.raw_txbytes(tx)
  end

  defp compute_sign_hash(tx) do
    with tx when not is_nil(tx) <- tx,
         do: TypedDataHash.hash_struct(tx)
  end

  defp respond({:ok, transaction}, result), do: {:ok, %{result: result, transactions: [transaction]}}

  defp respond(transactions, result) when is_list(transactions),
    do: {:ok, %{result: result, transactions: transactions}}

  defp respond(error, _), do: error
end
