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
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.WatcherInfo.DB

  require Transaction
  require Transaction.Payment

  @type currency_t() :: Transaction.Payment.currency()

  @type payment_t() :: %{
          owner: Crypto.address_t() | nil,
          currency: currency_t(),
          amount: pos_integer()
        }

  @type fee_t() :: %{
          currency: currency_t(),
          amount: non_neg_integer()
        }

  @type order_t() :: %{
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

  @type utxo_list_t() :: list(%DB.TxOutput{})

  @empty_metadata <<0::256>>

  @doc """
  Given order finds spender's inputs sufficient to perform a payment.
  If also provided with receiver's address, creates and encodes a transaction.
  TODO: seems unocovered by any tests
  """
  @spec create_advice(%{currency_t() => list(%DB.TxOutput{})}, order_t()) :: advice_t()
  def create_advice(utxos, %{owner: owner, payments: payments, fee: fee} = order) do
    needed_funds = needed_funds(payments, fee)
    token_utxo_selection = select_utxo(utxos, needed_funds)

    with {:ok, funds} <- funds_sufficient?(token_utxo_selection) do
      utxo_count =
        funds
        |> Stream.map(fn {_, utxos} -> length(utxos) end)
        |> Enum.sum()

      if utxo_count <= Transaction.Payment.max_inputs(),
        do: create_transaction(funds, order) |> respond(:complete),
        else: create_merge(owner, funds) |> respond(:intermediate)
    end
  end

  @spec prioritize_merge_utxos(%{currency_t() => utxo_list_t()}, utxo_list_t()) :: utxo_list_t()
  def prioritize_merge_utxos(selected_utxos, utxos) do
    selected_currencies = Map.keys(selected_utxos)

    selected_utxos_hashes =
      selected_utxos
      |> Enum.map(fn {_currency, utxos} -> utxos end)
      |> List.flatten()
      |> Enum.map(fn utxo -> utxo.child_chain_utxohash end)

    selected_currencies
    |> Enum.map(fn currency -> utxos[currency] end)
    |> Enum.sort_by(&length/1, :desc)
    |> List.flatten()
    |> Enum.filter(fn utxo -> !Enum.member?(selected_utxos_hashes, utxo.child_chain_utxohash) end)
  end

  @spec get_number_of_utxos(%{currency_t() => utxo_list_t()}) :: integer()
  def get_number_of_utxos(utxos_by_currency) do
    Enum.reduce(utxos_by_currency, 0, fn {_currency, utxos}, acc -> length(utxos) + acc end)
  end

  @doc """
  Given a map of UTXOs sufficient for the transaction and a set of available UTXOs,
  adds UTXOs to the transaction for "stealth merge" until the limit is reached or
  no UTXOs are available. Returns an updated map of UTXOs for the transaction.
  """
  @spec add_utxos_for_stealth_merge(%{currency_t() => utxo_list_t()}, utxo_list_t()) :: %{currency_t() => utxo_list_t()}
  def add_utxos_for_stealth_merge(selected_utxos, available_utxos) do
    cond do
      get_number_of_utxos(selected_utxos) == Transaction.Payment.max_inputs() ->
        selected_utxos

      Enum.empty?(available_utxos) ->
        selected_utxos

      true ->
        [priority_utxo | remaining_available_utxos] = available_utxos

        selected_utxos
        |> Map.update!(priority_utxo.currency, fn current_utxos -> [priority_utxo | current_utxos] end)
        |> add_utxos_for_stealth_merge(remaining_available_utxos)
    end
  end

  @doc """
  Given the available set of UTXOs and the needed amount by currency, tries to find a UTXO that satisfies the payment with no change.
  If this fails, starts to collect UTXOs (starting from the largest amount) until the payment is covered.
  Returns {currency, { variance, [utxos] }}. A `variance` greater than zero means insufficient funds.
  The ordering of UTXOs in descending order of amount is implicitly assumed for this algorithm to work deterministically.
  """
  @spec select_utxo(%{currency_t() => utxo_list_t()}, %{currency_t() => pos_integer()}) ::
          list({currency_t(), {integer, utxo_list_t()}})
  def select_utxo(utxos, needed_funds) do
    Enum.map(needed_funds, fn {token, need} ->
      token_utxos = Map.get(utxos, token, [])

      {token,
       case Enum.find(token_utxos, fn %DB.TxOutput{amount: amount} -> amount == need end) do
         nil ->
           Enum.reduce_while(token_utxos, {need, []}, fn
             _, {need, acc} when need <= 0 ->
               {:halt, {need, acc}}

             %DB.TxOutput{amount: amount} = utxo, {need, acc} ->
               {:cont, {need - amount, [utxo | acc]}}
           end)

         utxo ->
           {0, [utxo]}
       end}
    end)
  end

  @doc """
  Sums up payable amount by token, including the fee.
  """
  @spec needed_funds(list(payment_t()), %{amount: pos_integer(), currency: currency_t()}) ::
          %{currency_t() => pos_integer()}
  def needed_funds(payments, %{currency: fee_currency, amount: fee_amount}) do
    needed_funds =
      payments
      |> Enum.group_by(fn payment -> payment.currency end)
      |> Stream.map(fn {token, payment} ->
        {token, payment |> Stream.map(fn payment -> payment.amount end) |> Enum.sum()}
      end)
      |> Map.new()

    Map.update(needed_funds, fee_currency, fee_amount, fn amount -> amount + fee_amount end)
  end

  @doc """
  Checks if the result of `select_utxos/2` covers the amount(s) of the transaction order.
  """
  @spec funds_sufficient?([
          {currency :: currency_t(), {variance :: integer(), selected_utxos :: utxo_list_t()}}
        ]) ::
          {:ok, [{currency_t(), utxo_list_t()}]}
          | {:error, {:insufficient_funds, [%{token: String.t(), missing: pos_integer()}]}}
  def funds_sufficient?(utxo_selection) do
    missing_funds =
      utxo_selection
      |> Stream.filter(fn {_currency, {variance, _selected_utxos}} -> variance > 0 end)
      |> Enum.map(fn {currency, {missing, _selected_utxos}} ->
        %{token: Encoding.to_hex(currency), missing: missing}
      end)

    if Enum.empty?(missing_funds),
      do: {:ok, utxo_selection |> Enum.map(fn {token, {_missing_amount, utxos}} -> {token, utxos} end)},
      else: {:error, {:insufficient_funds, missing_funds}}
  end

  defp create_transaction(utxos_per_token, %{
         owner: owner,
         payments: payments,
         metadata: metadata,
         fee: fee
       }) do
    rests =
      utxos_per_token
      |> Stream.map(fn {token, utxos} ->
        outputs =
          [fee | payments]
          |> Stream.filter(&(&1.currency == token))
          |> Stream.map(& &1.amount)
          |> Enum.sum()

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
        raw_tx = create_raw_transaction(inputs, outputs, metadata)

        {:ok,
         %{
           inputs: inputs,
           outputs: outputs,
           fee: fee,
           metadata: metadata,
           txbytes: create_txbytes(raw_tx),
           sign_hash: compute_sign_hash(raw_tx)
         }}
    end
  end

  defp create_merge(owner, utxos_per_token) do
    utxos_per_token
    |> Enum.map(fn {token, utxos} ->
      Stream.chunk_every(utxos, Transaction.Payment.max_outputs())
      |> Enum.map(fn
        [_single_input] ->
          # merge not needed
          []

        inputs ->
          create_transaction([{token, inputs}], %{
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

  defp create_raw_transaction(inputs, outputs, metadata) do
    if Enum.any?(outputs, &(&1.owner == nil)),
      do: nil,
      else:
        Transaction.Payment.new(
          inputs |> Enum.map(&{&1.blknum, &1.txindex, &1.oindex}),
          outputs |> Enum.map(&{&1.owner, &1.currency, &1.amount}),
          metadata || @empty_metadata
        )
  end

  defp create_txbytes(tx) do
    with tx when not is_nil(tx) <- tx,
         do: Transaction.raw_txbytes(tx)
  end

  defp compute_sign_hash(tx) do
    with tx when not is_nil(tx) <- tx,
         do: TypedDataHash.hash_struct(tx)
  end

  defp respond({:ok, transaction}, result),
    do: {:ok, %{result: result, transactions: [transaction]}}

  defp respond(transactions, result) when is_list(transactions),
    do: {:ok, %{result: result, transactions: transactions}}

  defp respond(error, _), do: error
end
