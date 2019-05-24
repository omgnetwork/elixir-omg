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
  use OMG.API.LoggerExt

  alias OMG.API.State.Transaction
  alias OMG.API.Utxo
  alias OMG.Watcher.DB

  require Utxo

  import Ecto.Query, only: [from: 2, where: 3, select: 3, join: 5, distinct: 2]

  @type mined_block() :: %{
          transactions: [OMG.API.State.Transaction.Recovered.t()],
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

  def get_by_filters(address, blknum, limit) do
    query_get_last(limit)
    |> query_get_by_address(address)
    |> query_get_by_blknum(blknum)
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

  defp query_get_by_address(query, nil), do: query

  defp query_get_by_address(query, address) do
    query
    |> join(
      :inner,
      [t],
      o in DB.TxOutput,
      t.txhash == o.creating_txhash or
        t.txhash == o.spending_txhash
    )
    |> where([t, o], o.owner == ^address)
    |> select([t, o], t)
    |> distinct(true)
  end

  defp query_get_by_blknum(query, nil), do: query
  defp query_get_by_blknum(query, blknum), do: query |> from(where: [blknum: ^blknum])

  def get_by_blknum(blknum) do
    __MODULE__
    |> query_get_by_blknum(blknum)
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

    _ = Logger.info("Block ##{block_number} persisted in DB done in #{insert_duration / 1000}ms")

    result
  end

  @spec process(Transaction.Recovered.t(), pos_integer(), integer(), list()) :: [list()]
  defp process(
         %Transaction.Recovered{
           tx_hash: tx_hash,
           signed_tx: %Transaction.Signed{signed_tx_bytes: signed_tx_bytes, raw_tx: raw_tx = %Transaction{}}
         },
         block_number,
         txindex,
         [tx_list, output_list, input_list]
       ) do
    [
      [create(block_number, txindex, tx_hash, signed_tx_bytes) | tx_list],
      DB.TxOutput.create_outputs(block_number, txindex, tx_hash, raw_tx) ++ output_list,
      DB.TxOutput.create_inputs(raw_tx, tx_hash) ++ input_list
    ]
  end

  @spec create(pos_integer(), integer(), binary(), binary()) :: map()
  defp create(
         block_number,
         txindex,
         txhash,
         txbytes
       ) do
    %{
      txhash: txhash,
      txbytes: txbytes,
      blknum: block_number,
      txindex: txindex
    }
  end
end
