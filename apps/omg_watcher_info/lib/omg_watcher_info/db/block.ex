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
  @max_params_count 0xFFFF
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

    timestamps(type: :utc_datetime_usec)
  end

  @spec get_max_blknum() :: non_neg_integer()
  def get_max_blknum() do
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
  @spec get_blocks(Paginator.t(%DB.Block{})) :: Paginator.t(%DB.Block{})
  def get_blocks(paginator) do
    query_get_last(paginator.data_paging)
    |> DB.Repo.all()
    |> Paginator.set_data(paginator)
  end

  @spec query_timestamp_between(Ecto.Query.t(), non_neg_integer(), non_neg_integer()) ::
          Ecto.Query.t()
  def query_timestamp_between(query, start_datetime, end_datetime) do
    from(block in query,
      where:
        block.timestamp >= ^start_datetime and
          block.timestamp <= ^end_datetime
    )
  end

  @doc """
  Returns the total number of blocks in between given timestamps
  """
  @spec count_all_between_timestamps(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def count_all_between_timestamps(start_datetime, end_datetime) do
    query_count()
    |> query_timestamp_between(start_datetime, end_datetime)
    |> DB.Repo.one!()
  end

  @doc """
  Returns the total number of blocks
  """
  @spec count_all() :: non_neg_integer()
  def count_all() do
    DB.Repo.one!(query_count())
  end

  @doc """
  Returns a map with the timestamps of the earliest and latest blocks of all time.
  """
  @spec get_timestamp_range_all :: %{min: non_neg_integer(), max: non_neg_integer()}
  def get_timestamp_range_all() do
    DB.Repo.one!(query_timestamp_range())
  end

  @doc """
  Returns a map with the timestamps of the earliest and latest blocks within a given time range.
  """
  @spec get_timestamp_range_between(non_neg_integer(), non_neg_integer()) :: %{
          min: non_neg_integer(),
          max: non_neg_integer()
        }
  def get_timestamp_range_between(start_datetime, end_datetime) do
    query_timestamp_range()
    |> query_timestamp_between(start_datetime, end_datetime)
    |> DB.Repo.one!()
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

    db_txs_stream = chunk(db_txs)
    db_outputs_stream = chunk(db_outputs)

    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.insert("current_block", changeset(%__MODULE__{}, current_block), [])
      |> prepare_inserts(db_txs_stream, "db_txs_", DB.Transaction)
      |> prepare_inserts(db_outputs_stream, "db_outputs_", DB.TxOutput)
      |> DB.TxOutput.spend_utxos(db_inputs)

    {insert_duration, result} = :timer.tc(DB.Repo, :transaction, [multi])

    case result do
      {:ok, _} ->
        _ = Logger.info("Block \##{block_number} persisted in WatcherDB, done in #{insert_duration / 1000}ms")

        result

      {:error, changeset} ->
        _ = Logger.info("Block \##{block_number} not persisted in WatcherDB, done in #{insert_duration / 1000}ms")

        _ = Logger.info("Error: #{inspect(changeset.errors)}")
        result
    end
  end

  defp prepare_inserts(multi, stream, name, schema) do
    {ecto_multi, _} =
      Enum.reduce(stream, {multi, 0}, fn action, {multi, index} ->
        {Ecto.Multi.insert_all(multi, name <> "#{index}", schema, action), index + 1}
      end)

    ecto_multi
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
    raw_tx = Map.fetch!(tx, :raw_tx)
    tx_type = Map.fetch!(raw_tx, :tx_type)
    metadata = Map.get(raw_tx, :metadata)
    signed_tx_bytes = Map.fetch!(recovered_tx, :signed_tx_bytes)
    tx_hash = State.Transaction.raw_txhash(tx)

    transaction = create(block_number, txindex, tx_hash, tx_type, signed_tx_bytes, metadata)
    outputs = DB.TxOutput.create_outputs(block_number, txindex, tx_hash, tx)
    inputs = DB.TxOutput.create_inputs(tx, tx_hash)

    {transaction, outputs, inputs}
  end

  @spec create(pos_integer(), integer(), binary(), pos_integer(), binary(), State.Transaction.metadata()) ::
          map()
  defp create(block_number, txindex, txhash, txtype, txbytes, metadata) do
    %{
      txhash: txhash,
      txtype: txtype,
      txbytes: txbytes,
      blknum: block_number,
      txindex: txindex,
      metadata: metadata
    }
  end

  @spec query_timestamp_range() :: Ecto.Query.t()
  defp query_timestamp_range() do
    from(block in __MODULE__,
      select: %{
        max: max(block.timestamp),
        min: min(block.timestamp)
      }
    )
  end

  @spec query_count() :: Ecto.Query.t()
  defp query_count() do
    from(block in __MODULE__, select: count())
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

  # Prepares entries to the database in chunks to avoid `too many parameters` error.
  # Accepts the same parameters that `Repo.insert_all/3`.
  defp chunk(entries) do
    utc_now = DateTime.utc_now()
    entries = Enum.map(entries, fn entry -> Map.merge(entry, %{inserted_at: utc_now, updated_at: utc_now}) end)

    chunk_size = entries |> hd() |> chunk_size()

    Stream.chunk_every(entries, chunk_size)
  end

  # Note: an entry with 0 fields will cause a divide-by-zero error.
  #
  # DB.Repo.chunk_size(%{}) ==> (ArithmeticError) bad argument in arithmetic expression
  #
  # But we could not think of a case where this code happen, so no defensive
  # checks here.
  def chunk_size(entry), do: div(@max_params_count, fields_count(entry))

  defp fields_count(map), do: Kernel.map_size(map)
end
