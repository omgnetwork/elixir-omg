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

defmodule OMG.WatcherInfo.DB.Block do
  @moduledoc """
  Ecto schema for Plasma Chain block
  """
  use Ecto.Schema
  use OMG.Utils.LoggerExt
  import Ecto.Changeset

  alias OMG.State
  alias OMG.Utils.Paginator
  alias OMG.WatcherInfo.DB

  import Ecto.Query, only: [from: 2]

  @type mined_block() :: %{
          transactions: [State.Transaction.Recovered.t()],
          blknum: pos_integer(),
          blkhash: <<_::256>>,
          timestamp: pos_integer(),
          eth_height: pos_integer()
        }

  @primary_key {:blknum, :integer, []}
  @derive {Phoenix.Param, key: :blknum}
  schema "blocks" do
    field(:hash, :binary)
    field(:eth_height, :integer)
    field(:timestamp, :integer)
    field(:tx_count, :integer, virtual: true, default: nil)

    has_many(:transactions, DB.Transaction, foreign_key: :blknum)
  end

  defp changeset(block, params) do
    block
    |> cast(params, [:blknum, :hash, :timestamp, :eth_height])
    |> unique_constraint(:blknum, name: :blocks_pkey)
    |> validate_required([:blknum, :hash, :timestamp, :eth_height])
    |> validate_number(:blknum, greater_than: 0)
    |> validate_number(:timestamp, greater_than: 0)
    |> validate_number(:eth_height, greater_than: 0)
  end

  @spec get_max_blknum() :: non_neg_integer()
  def get_max_blknum do
    DB.Repo.aggregate(__MODULE__, :max, :blknum)
  end

  @doc """
    Gets a block specified by a block number.
  """
  def get(blknum) do
    query =
      from(
        block in base_query(),
        where: [blknum: ^blknum]
      )

    DB.Repo.one(query)
  end

  def base_query() do
    from(
      block in __MODULE__,
      left_join: tx in assoc(block, :transactions),
      group_by: block.blknum,
      select: %{block | tx_count: count(tx.txhash)}
    )
  end

  @doc """
  Returns a list of blocks
  """
  @spec get_blocks(Paginator.t()) :: Paginator.t()
  def get_blocks(paginator) do
    query_get_last(paginator.data_paging)
    |> DB.Repo.all()
    |> Paginator.set_data(paginator)
  end

  defp query_get_last(%{limit: limit, page: page}) do
    offset = (page - 1) * limit

    from(
      block in base_query(),
      order_by: [desc: :blknum],
      limit: ^limit,
      offset: ^offset
    )
  end

  @spec insert(map()) :: {:ok, %__MODULE__{}} | {:error, Ecto.Changeset.t()}
  def insert(params) do
    %__MODULE__{}
    |> changeset(params)
    |> DB.Repo.insert()
  end

  @doc """
  Inserts complete and sorted enumerable of transactions for particular block number
  """
  @spec insert_with_transactions(mined_block()) :: {:ok, %__MODULE__{}}
  def insert_with_transactions(%{
        transactions: transactions,
        blknum: block_number,
        blkhash: blkhash,
        timestamp: timestamp,
        eth_height: eth_height
      }) do
    {db_txs, db_outputs, db_inputs} = prepare_db_transactions(transactions, block_number)

    current_block = %{
      blknum: block_number,
      hash: blkhash,
      timestamp: timestamp,
      eth_height: eth_height
    }

    {insert_duration, result} =
      :timer.tc(
        &DB.Repo.transaction/1,
        [
          fn ->
            with {:ok, block} <- insert(current_block),
                 :ok <- DB.Repo.insert_all_chunked(DB.Transaction, db_txs),
                 :ok <- DB.Repo.insert_all_chunked(DB.TxOutput, db_outputs),
                 # inputs are set as spent after outputs are inserted to support spending utxo from the same block
                 :ok <- DB.TxOutput.spend_utxos(db_inputs) do
              block
            else
              {:error, changeset} -> DB.Repo.rollback(changeset)
            end
          end
        ]
      )

    case result do
      {:ok, _} ->
        _ = Logger.debug("Block \##{block_number} persisted in WatcherDB, done in #{insert_duration / 1000}ms")

        result

      {:error, changeset} ->
        _ = Logger.debug("Block \##{block_number} not persisted in WatcherDB, done in #{insert_duration / 1000}ms")

        _ = Logger.debug("Error: #{inspect(changeset.errors)}")
        result
    end
  end

  @spec prepare_db_transactions(State.Transaction.Recovered.t(), pos_integer()) ::
          {[map()], [%DB.TxOutput{}], [%DB.TxOutput{}]}
  defp prepare_db_transactions(mined_transactions, block_number) do
    mined_transactions
    |> Stream.with_index()
    |> Enum.reduce({[], [], []}, fn {tx, txindex}, {tx_list, output_list, input_list} ->
      {tx, outputs, inputs} = prepare_db_transaction(tx, block_number, txindex)
      {[tx | tx_list], outputs ++ output_list, inputs ++ input_list}
    end)
  end

  @spec prepare_db_transaction(State.Transaction.Recovered.t(), pos_integer(), integer()) :: [
          {map(), [%DB.TxOutput{}], [%DB.TxOutput{}]}
        ]
  defp prepare_db_transaction(recovered_tx, block_number, txindex) do
    tx = Map.fetch!(recovered_tx, :signed_tx)
    metadata = tx |> Map.fetch!(:raw_tx) |> Map.fetch!(:metadata)
    signed_tx_bytes = Map.fetch!(recovered_tx, :signed_tx_bytes)
    tx_hash = State.Transaction.raw_txhash(tx)

    transaction = create(block_number, txindex, tx_hash, signed_tx_bytes, metadata)
    outputs = DB.TxOutput.create_outputs(block_number, txindex, tx_hash, tx)
    inputs = DB.TxOutput.create_inputs(tx, tx_hash)

    {transaction, outputs, inputs}
  end

  @spec create(pos_integer(), integer(), binary(), binary(), State.Transaction.metadata()) ::
          map()
  defp create(block_number, txindex, txhash, txbytes, metadata) do
    %{
      txhash: txhash,
      txbytes: txbytes,
      blknum: block_number,
      txindex: txindex,
      metadata: metadata
    }
  end
end
