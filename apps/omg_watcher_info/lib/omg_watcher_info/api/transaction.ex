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

defmodule OMG.WatcherInfo.API.Transaction do
  @moduledoc """
  Module provides API for transactions
  """

  alias OMG.State.Transaction
  alias OMG.Utils.Paginator
  alias OMG.Utxo
  alias OMG.WatcherInfo.DB
  alias OMG.WatcherInfo.HttpRPC.Client
  alias OMG.WatcherInfo.UtxoSelection

  require Utxo

  @default_transactions_limit 200
  @empty_metadata <<0::256>>

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
  @spec get_transactions(Keyword.t()) :: Paginator.t()
  def get_transactions(constraints) do
    paginator = Paginator.from_constraints(constraints, @default_transactions_limit)

    constraints
    |> Keyword.drop([:limit, :page])
    |> DB.Transaction.get_by_filters(paginator)
  end

  @doc """
  Passes the signed transaction to the child chain.

  Caution: This function is unaware of the child chain's security status, e.g.:

  * Watcher is fully synced,
  * all operator blocks have been verified,
  * transaction doesn't spend funds not yet mined
  * etc...
  """
  @spec submit(Transaction.Signed.t()) :: Client.response_t() | {:error, atom()}
  def submit(%Transaction.Signed{} = signed_tx) do
    url = Application.get_env(:omg_watcher_info, :child_chain_url)

    signed_tx
    |> Transaction.Signed.encode()
    |> Client.submit(url)
  end

  @doc """
  Given order finds spender's inputs sufficient to perform a payment.
  If also provided with receiver's address, creates and encodes a transaction.
  """
  @spec create(UtxoSelection.order_t()) :: UtxoSelection.advice_t()
  def create(order) do
    utxos = DB.TxOutput.get_sorted_grouped_utxos(order.owner)
    UtxoSelection.create_advice(utxos, order)
  end

  @spec include_typed_data(UtxoSelection.advice_t()) :: UtxoSelection.advice_t()
  def include_typed_data({:error, _} = err), do: err

  def include_typed_data({:ok, %{transactions: txs} = advice}),
    do: {
      :ok,
      %{advice | transactions: Enum.map(txs, fn tx -> Map.put_new(tx, :typed_data, add_type_specs(tx)) end)}
    }

  defp add_type_specs(%{inputs: inputs, outputs: outputs, metadata: metadata}) do
    alias OMG.TypedDataHash

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
    empty_gen = fn -> %{blknum: 0, txindex: 0, oindex: 0} end

    inputs
    |> Stream.map(&Map.take(&1, [:blknum, :txindex, :oindex]))
    |> Stream.concat(Stream.repeatedly(empty_gen))
    |> (&Enum.zip([:input0, :input1, :input2, :input3], &1)).()
  end

  defp create_outputs(outputs) do
    zero_addr = OMG.Eth.zero_address()
    empty_gen = fn -> %{owner: zero_addr, currency: zero_addr, amount: 0} end

    outputs
    |> Stream.concat(Stream.repeatedly(empty_gen))
    |> (&Enum.zip([:output0, :output1, :output2, :output3], &1)).()
  end
end
