# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.WatcherInformational.DB.Transaction do
  @moduledoc """
  Ecto Schema representing a transaction
  """
  use Ecto.Schema
  use OMG.Utils.LoggerExt

  alias OMG.Utils.Paginator
  alias OMG.Utxo
  alias OMG.WatcherInformational.DB

  require Utxo

  import Ecto.Query, only: [from: 2, where: 2, where: 3, select: 3, join: 5, distinct: 2]

  @primary_key {:txhash, :binary, []}
  @derive {Phoenix.Param, key: :txhash}
  @derive {Jason.Encoder, except: [:__meta__]}
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
  Returns transactions possibly filtered by constraints
  * constraints - accepts keyword in the form of [schema_field: value]
  """
  @spec get_by_filters(Keyword.t(), Paginator.t()) :: Paginator.t()
  def get_by_filters(constraints, paginator) do
    allowed_constraints = [:address, :blknum, :txindex, :metadata]

    constraints = filter_constraints(constraints, allowed_constraints)

    # we need to handle complex constraints with dedicated modifier function
    {address, constraints} = Keyword.pop(constraints, :address)

    query_get_last(paginator.data_paging)
    |> query_get_by_address(address)
    |> query_get_by(constraints)
    |> DB.Repo.all()
    |> Paginator.set_data(paginator)
  end

  defp query_get_last(%{limit: limit, page: page}) do
    offset = (page - 1) * limit

    from(
      __MODULE__,
      order_by: [desc: :blknum, desc: :txindex],
      limit: ^limit,
      offset: ^offset,
      preload: [:block, :outputs]
    )
  end

  defp query_get_by_address(query, nil), do: query

  defp query_get_by_address(query, address) do
    query
    |> join(:inner, [t], o in DB.TxOutput, on: t.txhash == o.creating_txhash or t.txhash == o.spending_txhash)
    |> where([t, o], o.owner == ^address)
    |> select([t, o], t)
    |> distinct(true)
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
