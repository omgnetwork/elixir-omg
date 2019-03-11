# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.Watcher.API.Transaction do
  @moduledoc """
  Module provides API for transactions
  """

  alias OMG.API.Crypto
  alias OMG.API.State.Transaction
  alias OMG.API.Utxo
  alias OMG.RPC.Client
  alias OMG.Watcher.DB

  require Utxo
  require Transaction

  @default_transactions_limit 200

  @doc """
  Retrieves a specific transaction by id
  """
  @spec get(binary()) :: {:ok, %DB.Transaction{}} | {:error, :transaction_not_found}
  def get(transaction_id) do
    if transaction = DB.Transaction.get(transaction_id),
      do: {:ok, transaction},
      else: {:error, :transaction_not_found}
  end

  @doc """
  Retrieves a list of transactions that:
   - (optionally) a given address is involved as input or output owner.
   - (optionally) belong to a given child block number

  Length of the list is limited by `limit` argument
  """
  @spec get_transactions(nil | Crypto.address_t(), nil | pos_integer(), pos_integer()) ::
          list(%DB.Transaction{})
  def get_transactions(address, blknum, limit) do
    limit = limit || @default_transactions_limit
    # TODO: implement pagination. Defend against fetching huge dataset.
    limit = min(limit, @default_transactions_limit)
    DB.Transaction.get_by_filters(address, blknum, limit)
  end

  @doc """
  Passes signed transaction to the child chain only if it's secure, e.g.
  * Watcher is fully synced,
  * all operator blocks have been verified,
  * transaction doesn't spend funds not yet mined
  * etc...

  Note: No validation for now, just passes given tx to the child chain. See: OMG-410
  """
  @spec submit(binary()) :: Client.response_t()
  def(submit(txbytes)) do
    Client.submit(txbytes)
  end

  @type payment_t() :: %{
          owner: Crypto.address_t() | nil,
          currency: Transaction.currency(),
          amount: pos_integer()
        }

  @type fee_t() :: %{
          currency: Transaction.currency(),
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
          fee: %{amount: integer, currency: Transaction.currency()},
          txbytes: Transaction.tx_bytes() | nil,
          metadata: Transaction.metadata()
        }

  @type create_advice_t() ::
          {:ok,
           %{
             result: :complete | :intermediate,
             transactions: nonempty_list(transaction_t())
           }}
          | {:error, :insufficient_funds, list(map())}
          | {:error, :too_many_outputs}

  @doc """
  Given order finds spender's inputs sufficient to perform a payment.
  If also provided with receiver's address, creates and encodes a transaction.
  """
  @spec create(order_t()) :: create_advice_t()
  def create(%{owner: owner, payments: payments, fee: fee} = order) do
    needed_funds = needed_funds(payments, fee)
    token_utxo_selection = select_utxo(owner, needed_funds)

    with {:ok, funds} <- funds_sufficient?(token_utxo_selection) do
      utxo_count =
        funds
        |> Enum.map(fn {_, utxos} -> length(utxos) end)
        |> Enum.sum()

      if utxo_count <= Transaction.max_inputs(),
        do: create_transaction(funds, order) |> respond(:complete),
        else: create_merge(owner, funds) |> respond(:intermediate)
    end
  end

  defp needed_funds(payments, %{currency: fee_currency, amount: fee_amount}) do
    needed_funds =
      payments
      |> Enum.group_by(& &1.currency)
      |> Enum.map(fn {k, v} ->
        {k, v |> Enum.map(& &1.amount) |> Enum.sum()}
      end)
      |> Map.new()

    Map.update(needed_funds, fee_currency, fee_amount, &(&1 + fee_amount))
  end

  defp select_utxo(owner, needed_funds) do
    utxos = DB.TxOutput.get_sorted_grouped_utxos(owner)

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

  defp funds_sufficient?(utxo_selection) do
    missing_funds =
      utxo_selection
      |> Enum.filter(fn {_, {short, _}} -> short > 0 end)
      |> Enum.map(fn {token, {short, _}} -> %{token: OMG.RPC.Web.Encoding.to_hex(token), missing: short} end)

    if Enum.empty?(missing_funds),
      do: {:ok, utxo_selection |> Enum.map(fn {token, {_, utxos}} -> {token, utxos} end)},
      else: {:error, :insufficient_funds, missing_funds}
  end

  defp create_transaction(utxos_per_token, %{owner: owner, payments: payments, metadata: metadata, fee: fee}) do
    rests =
      utxos_per_token
      |> Enum.map(fn {token, utxos} ->
        outputs = [fee | payments] |> Enum.filter(&(&1.currency == token)) |> Enum.map(& &1.amount) |> Enum.sum()

        inputs = utxos |> Enum.map(& &1.amount) |> Enum.sum()
        %{amount: inputs - outputs, owner: owner, currency: token}
      end)
      |> Enum.filter(&(&1.amount > 0))

    outputs = payments ++ rests

    inputs =
      utxos_per_token
      |> Enum.map(fn {_, utxos} -> utxos end)
      |> List.flatten()

    if(Enum.count(outputs) > Transaction.max_outputs(),
      do: {:error, :too_many_outputs},
      else:
        {:ok,
         %{
           inputs: inputs,
           outputs: outputs,
           fee: fee,
           metadata: metadata,
           txbytes: create_txbytes(inputs, outputs, metadata)
         }}
    )
  end

  defp create_merge(owner, utxos_per_token) do
    utxos_per_token
    |> Enum.map(fn {token, utxos} ->
      Enum.chunk_every(utxos, Transaction.max_outputs())
      |> Enum.map(fn
        [_single_input] ->
          # merge not needed
          []

        inputs ->
          create_transaction([{token, inputs}], %{
            fee: %{amount: 0, currency: token},
            metadata: nil,
            owner: owner,
            payments: []
          })
      end)
    end)
    |> List.flatten()
    |> Enum.map(fn {:ok, tx} -> tx end)
  end

  defp create_txbytes(inputs, outputs, metadata) do
    if Enum.any?(outputs, &(&1.owner == nil)),
      do: nil,
      else:
        Transaction.new(
          inputs |> Enum.map(&{&1.blknum, &1.txindex, &1.oindex}),
          outputs |> Enum.map(&{&1.owner, &1.currency, &1.amount}),
          metadata
        )
        |> Transaction.encode()
  end

  defp respond({:ok, transaction}, result), do: {:ok, %{result: result, transactions: [transaction]}}

  defp respond(transactions, result) when is_list(transactions),
    do: {:ok, %{result: result, transactions: transactions}}

  defp respond(error, _), do: error
end
