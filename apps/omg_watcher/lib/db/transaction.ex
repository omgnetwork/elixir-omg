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

defmodule OMG.Watcher.DB.Transaction do
  @moduledoc """
  Ecto Schema representing a transaction
  """
  use Ecto.Schema
  use OMG.LoggerExt

  alias OMG.State.Transaction
  alias OMG.Utxo
  alias OMG.Watcher.DB

  require Utxo

  import Ecto.Query, only: [from: 2, where: 2]

  @type mined_block() :: %{
          transactions: [OMG.State.Transaction.Recovered.t()],
          blknum: pos_integer(),
          blkhash: <<_::256>>,
          timestamp: pos_integer(),
          eth_height: pos_integer()
        }

  @primary_key {:txhash, :binary, []}
  @derive {Phoenix.Param, key: :txhash}
  @derive {Poison.Encoder, except: [:__meta__]}
  schema "transactions" do
    field(:txindex, :integer)
    field(:txbytes, :binary)
    field(:sent_at, :utc_datetime)
    field(:metadata, :binary)

    has_many(:inputs, DB.TxOutput, foreign_key: :spending_txhash)
    has_many(:outputs, DB.TxOutput, foreign_key: :creating_txhash)
    belongs_to(:block, DB.Block, foreign_key: :blknum, references: :blknum, type: :integer)
  end

  @doc """
    Gets a transaction specified by a hash.
    Optionally, fetches block which the transaction was included in.
  """
  def get(hash) do
    query =
      from(
        __MODULE__,
        where: [txhash: ^hash],
        preload: [
          :block,
          inputs: ^from(txo in DB.TxOutput, order_by: :spending_tx_oindex),
          outputs: ^from(txo in DB.TxOutput, order_by: :oindex)
        ]
      )

    DB.Repo.one(query)
  end

  @doc """
  Returns transactions possibly filtered by constrains
  * constrains - accepts keyword in the form of [schema_field: value]
  """
  @spec get_by_filters(Keyword.t()) :: list(%__MODULE__{})
  def get_by_filters(constrains) do
    allowed_constrains = [:limit, :address, :blknum, :txindex, :metadata]

    constrains = filter_constrains(constrains, allowed_constrains)

    # we need to handle complex constrains with dedicated modifier function
    {limit, constrains} = Keyword.pop(constrains, :limit)
    {address, constrains} = Keyword.pop(constrains, :address)

    query_get_last(limit)
    |> query_get_by_address(address)
    |> query_get_by(constrains)
    |> DB.Repo.all()
  end

  defp query_get_last(limit) do
    from(
      __MODULE__,
      order_by: [desc: :blknum, desc: :txindex],
      limit: ^limit,
      preload: [:block, :outputs]
    )
  end

  defp query_get_by_address(base, nil), do: base

  defp query_get_by_address(base, address) do
    from(
      tx in base,
      distinct: true,
      left_join: output in assoc(tx, :outputs),
      left_join: input in assoc(tx, :inputs),
      where: output.owner == ^address or input.owner == ^address
    )
  end

  defp query_get_by(query, constrains) when is_list(constrains), do: query |> where(^constrains)

  def get_by_blknum(blknum) do
    __MODULE__
    |> query_get_by(blknum: blknum)
    |> from(order_by: [asc: :txindex])
    |> DB.Repo.all()
  end

  def get_by_position(blknum, txindex) do
    DB.Repo.one(from(__MODULE__, where: [blknum: ^blknum, txindex: ^txindex]))
  end

  @doc """
  Inserts complete and sorted enumerable of transactions for particular block number
  """
  @spec update_with(mined_block()) :: {:ok, any()}
  def update_with(%{
        transactions: transactions,
        blknum: block_number,
        blkhash: blkhash,
        timestamp: timestamp,
        eth_height: eth_height
      }) do
    [db_txs, db_outputs, db_inputs] =
      transactions
      |> Stream.with_index()
      |> Enum.reduce([[], [], []], fn {tx, txindex}, acc -> process(tx, block_number, txindex, acc) end)

    current_block = %DB.Block{blknum: block_number, hash: blkhash, timestamp: timestamp, eth_height: eth_height}

    {insert_duration, {:ok, _} = result} =
      :timer.tc(
        &DB.Repo.transaction/1,
        [
          fn ->
            {:ok, _} = DB.Repo.insert(current_block)
            _ = DB.Repo.insert_all_chunked(__MODULE__, db_txs)
            _ = DB.Repo.insert_all_chunked(DB.TxOutput, db_outputs)

            # inputs are set as spent after outputs are inserted to support spending utxo from the same block
            DB.TxOutput.spend_utxos(db_inputs)
          end
        ]
      )

    _ = Logger.debug("Block \##{block_number} persisted in WatcherDB, done in #{insert_duration / 1000}ms")

    result
  end

  @spec process(Transaction.Recovered.t(), pos_integer(), integer(), list()) :: [list()]
  defp process(
         %Transaction.Recovered{
           tx_hash: tx_hash,
           signed_tx: %Transaction.Signed{
             signed_tx_bytes: signed_tx_bytes,
             raw_tx: %Transaction{metadata: metadata} = raw_tx
           }
         },
         block_number,
         txindex,
         [tx_list, output_list, input_list]
       ) do
    [
      [create(block_number, txindex, tx_hash, signed_tx_bytes, metadata) | tx_list],
      DB.TxOutput.create_outputs(block_number, txindex, tx_hash, raw_tx) ++ output_list,
      DB.TxOutput.create_inputs(raw_tx, tx_hash) ++ input_list
    ]
  end

  @spec create(pos_integer(), integer(), binary(), binary(), Transaction.metadata()) ::
          map()
  defp create(
         block_number,
         txindex,
         txhash,
         txbytes,
         metadata
       ) do
    %{
      txhash: txhash,
      txbytes: txbytes,
      blknum: block_number,
      txindex: txindex,
      metadata: metadata
    }
  end

  defp filter_constrains(constrains, allowed_constrains) do
    case Keyword.drop(constrains, allowed_constrains) do
      [{out_of_schema, _} | _] ->
        _ =
          Logger.warn("Constrain on #{inspect(out_of_schema)} does not exist in schema and was dropped from the query")

        constrains |> Keyword.take(allowed_constrains)

      [] ->
        constrains
    end
  end
end
