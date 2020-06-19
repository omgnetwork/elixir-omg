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

defmodule OMG.WatcherInfo.DB.Transaction do
  @moduledoc """
  Ecto Schema representing a transaction
  """
  use Ecto.Schema
  use OMG.Utils.LoggerExt

  alias OMG.Utils.Paginator
  alias OMG.Utxo
  alias OMG.WatcherInfo.DB

  require Utxo

  import Ecto.Query, only: [from: 2, where: 2, where: 3, select: 3, join: 5, distinct: 2]

  @primary_key {:txhash, :binary, []}
  @derive {Phoenix.Param, key: :txhash}
  @derive {Jason.Encoder, except: [:__meta__]}
  schema "transactions" do
    field(:txindex, :integer)
    field(:txtype, :integer)
    field(:txbytes, :binary)
    field(:metadata, :binary)

    has_many(:inputs, DB.TxOutput, foreign_key: :spending_txhash)
    has_many(:outputs, DB.TxOutput, foreign_key: :creating_txhash)
    belongs_to(:block, DB.Block, foreign_key: :blknum, references: :blknum, type: :integer)

    timestamps(type: :utc_datetime_usec)
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
          block: ^DB.Block.base_query(),
          inputs: ^from(txo in DB.TxOutput, order_by: :spending_tx_oindex),
          outputs: ^from(txo in DB.TxOutput, order_by: :oindex)
        ]
      )

    DB.Repo.one(query)
  end

  @doc """
  Returns transactions possibly filtered by constraints
  * constraints - accepts keyword in the form of [schema_field: value]
  """
  @spec get_by_filters(Keyword.t(), Paginator.t(%__MODULE__{})) :: Paginator.t(%__MODULE__{})
  def get_by_filters(constraints, paginator) do
    allowed_constraints = [:address, :blknum, :txindex, :txtypes, :metadata, :end_datetime]

    constraints = filter_constraints(constraints, allowed_constraints)

    # we need to handle complex constraints with dedicated modifier function
    {address, constraints} = Keyword.pop(constraints, :address)
    {txtypes, constraints} = Keyword.pop(constraints, :txtypes)
    {end_datetime, constraints} = Keyword.pop(constraints, :end_datetime, :os.system_time(:second))
    params = Map.merge(paginator.data_paging, %{end_datetime: end_datetime})

    query_get_last(params)
    |> query_get_by_address(address)
    |> query_get_by_txtypes(txtypes)
    |> query_get_by(constraints)
    |> DB.Repo.all()
    |> Paginator.set_data(paginator)
  end

  defp query_get_last(%{limit: limit, page: page, end_datetime: end_datetime}) do
    offset = (page - 1) * limit

    from(transaction in __MODULE__,
      join: block in assoc(transaction, :block),
      order_by: [desc: :blknum, desc: :txindex],
      limit: ^limit,
      offset: ^offset,
      where: block.timestamp <= ^end_datetime,
      preload: [
        :block,
        inputs: ^from(txo in DB.TxOutput, order_by: :spending_tx_oindex),
        outputs: ^from(txo in DB.TxOutput, order_by: :oindex)
      ]
    )
  end

  @spec query_count() :: Ecto.Query.t()
  defp query_count() do
    from(transaction in __MODULE__, select: count())
  end

  @spec query_timestamp_between(Ecto.Query.t(), non_neg_integer(), non_neg_integer()) :: Ecto.Query.t()
  def query_timestamp_between(query, start_datetime, end_datetime) do
    from(transaction in query,
      join: block in assoc(transaction, :block),
      where:
        block.timestamp >= ^start_datetime and
          block.timestamp <= ^end_datetime
    )
  end

  @doc """
  Returns the total number of transactions between the given timestamps.
  """
  @spec count_all_between_timestamps(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def count_all_between_timestamps(start_datetime, end_datetime) do
    query_count()
    |> query_timestamp_between(start_datetime, end_datetime)
    |> DB.Repo.one!()
  end

  @doc """
  Returns the total number of transactions
  """
  @spec count_all() :: non_neg_integer()
  def count_all() do
    DB.Repo.one!(query_count())
  end

  defp query_get_by_address(query, nil), do: query

  defp query_get_by_address(query, address) do
    query
    |> join(:inner, [t], o in DB.TxOutput, on: t.txhash == o.creating_txhash or t.txhash == o.spending_txhash)
    |> where([t, o], o.owner == ^address)
    |> select([t, o], t)
    |> distinct(true)
  end

  defp query_get_by_txtypes(query, nil), do: query
  defp query_get_by_txtypes(query, []), do: query

  defp query_get_by_txtypes(query, txtypes) do
    where(query, [t], t.txtype in ^txtypes)
  end

  defp query_get_by(query, constraints) when is_list(constraints), do: query |> where(^constraints)

  @spec get_by_blknum(pos_integer) :: list(%__MODULE__{})
  def get_by_blknum(blknum) do
    __MODULE__
    |> query_get_by(blknum: blknum)
    |> from(order_by: [asc: :txindex])
    |> DB.Repo.all()
  end

  def get_by_position(blknum, txindex) do
    DB.Repo.one(from(__MODULE__, where: [blknum: ^blknum, txindex: ^txindex]))
  end

  defp filter_constraints(constraints, allowed_constraints) do
    case Keyword.drop(constraints, allowed_constraints) do
      [{out_of_schema, _} | _] ->
        _ =
          Logger.warn("Constraint on #{inspect(out_of_schema)} does not exist in schema and was dropped from the query")

        constraints |> Keyword.take(allowed_constraints)

      [] ->
        constraints
    end
  end
end
