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

defmodule OMG.WatcherInfo.DB.TxOutput do
  @moduledoc """
  Ecto schema for transaction's output or input
  """
  use Ecto.Schema
  use Spandex.Decorators

  alias OMG.State.Transaction
  alias OMG.Utils.Paginator
  alias OMG.Utxo
  alias OMG.WatcherInfo.DB
  alias OMG.WatcherInfo.DB.Repo

  require Utxo

  import Ecto.Query, only: [from: 2]

  @default_get_utxos_limit 200

  @type balance() :: %{
          currency: binary(),
          amount: non_neg_integer()
        }

  @type exit_t() :: %{
          utxo_pos: pos_integer(),
          txbytes: binary(),
          proof: binary(),
          sigs: binary()
        }

  @type order_t() :: :asc | :desc

  @primary_key false
  schema "txoutputs" do
    field(:blknum, :integer, primary_key: true)
    field(:txindex, :integer, primary_key: true)
    field(:oindex, :integer, primary_key: true)
    field(:owner, :binary)
    field(:otype, :integer)
    field(:amount, OMG.WatcherInfo.DB.Types.IntegerType)
    field(:currency, :binary)
    field(:proof, :binary)
    field(:spending_tx_oindex, :integer)
    field(:child_chain_utxohash, :binary)

    belongs_to(:creating_transaction, DB.Transaction, foreign_key: :creating_txhash, references: :txhash, type: :binary)
    belongs_to(:spending_transaction, DB.Transaction, foreign_key: :spending_txhash, references: :txhash, type: :binary)

    many_to_many(
      :ethevents,
      DB.EthEvent,
      join_through: DB.EthEventTxOutput,
      join_keys: [child_chain_utxohash: :child_chain_utxohash, root_chain_txhash_event: :root_chain_txhash_event]
    )

    timestamps(type: :utc_datetime_usec)
  end

  # preload ethevents in a single query as there will not be a large number of them
  @spec get_by_position(Utxo.Position.t()) :: map() | nil
  @decorate trace(service: :ecto, type: :db, tracer: OMG.WatcherInfo.Tracer)
  def get_by_position(Utxo.position(blknum, txindex, oindex)) do
    Repo.one(
      from(txoutput in __MODULE__,
        preload: [:ethevents],
        left_join: ethevent in assoc(txoutput, :ethevents),
        where: txoutput.blknum == ^blknum and txoutput.txindex == ^txindex and txoutput.oindex == ^oindex
      )
    )
  end

  @spec get_by_output_id(txhash :: OMG.Crypto.hash_t(), oindex :: non_neg_integer()) :: map() | nil
  @decorate trace(service: :ecto, type: :db, tracer: OMG.WatcherInfo.Tracer)
  def get_by_output_id(txhash, oindex) do
    Repo.one(
      from(txoutput in __MODULE__,
        preload: [:ethevents],
        left_join: ethevent in assoc(txoutput, :ethevents),
        where: txoutput.creating_txhash == ^txhash and txoutput.oindex == ^oindex
      )
    )
  end

  @spec get_utxos(keyword) :: OMG.Utils.Paginator.t(%__MODULE__{})
  @decorate trace(service: :ecto, type: :db, tracer: OMG.WatcherInfo.Tracer)
  def get_utxos(params) do
    address = Keyword.fetch!(params, :address)
    paginator = Paginator.from_constraints(params, @default_get_utxos_limit)
    %{limit: limit, page: page} = paginator.data_paging
    offset = (page - 1) * limit

    address
    |> query_get_utxos()
    |> from(limit: ^limit, offset: ^offset)
    |> Repo.all()
    |> Paginator.set_data(paginator)
  end

  @spec get_balance(OMG.Crypto.address_t()) :: list(balance())
  @decorate trace(service: :ecto, type: :db, tracer: OMG.WatcherInfo.Tracer)
  def get_balance(owner) do
    query =
      from(
        txoutput in __MODULE__,
        left_join: ethevent in assoc(txoutput, :ethevents),
        # select txoutputs by owner that have neither been spent nor have a corresponding ethevents exit events
        where:
          txoutput.owner == ^owner and is_nil(txoutput.spending_txhash) and
            (is_nil(ethevent) or
               fragment(
                 "
 NOT EXISTS (SELECT 1
             FROM ethevents_txoutputs AS etfrag
             JOIN ethevents AS efrag ON
                      etfrag.root_chain_txhash_event=efrag.root_chain_txhash_event
                      AND efrag.event_type = ANY(?)
                      AND etfrag.child_chain_utxohash = ?)",
                 ["standard_exit", "in_flight_exit"],
                 txoutput.child_chain_utxohash
               )),
        group_by: txoutput.currency,
        select: {txoutput.currency, sum(txoutput.amount)}
      )

    Repo.all(query)
    |> Enum.map(fn {currency, amount} ->
      # defends against sqlite that returns integer here
      amount = amount |> Decimal.new() |> Decimal.to_integer()
      %{currency: currency, amount: amount}
    end)
  end

  @spec spend_utxos(Ecto.Multi.t(), [map()]) :: Ecto.Multi.t()
  def spend_utxos(multi, db_inputs) do
    utc_now = DateTime.utc_now()

    {multi0, _} =
      Enum.reduce(db_inputs, {multi, 0}, fn data, {multi, index} ->
        {Utxo.position(blknum, txindex, oindex), spending_oindex, spending_txhash} = data

        {Ecto.Multi.update_all(
           multi,
           "spend_utxos_#{index}",
           from(p in DB.TxOutput,
             where: p.blknum == ^blknum and p.txindex == ^txindex and p.oindex == ^oindex
           ),
           set: [
             spending_tx_oindex: spending_oindex,
             spending_txhash: spending_txhash,
             updated_at: utc_now
           ]
         ), index + 1}
      end)

    multi0
  end

  @spec create_outputs(pos_integer(), integer(), binary(), Transaction.any_flavor_t()) :: [map()]
  def create_outputs(blknum, txindex, txhash, tx) do
    # zero-value outputs are not inserted, tx can have no outputs at all
    outputs =
      tx
      |> Transaction.get_outputs()
      |> Enum.with_index()
      |> Enum.flat_map(fn {%{currency: currency, owner: owner, amount: amount, output_type: otype}, oindex} ->
        create_output(otype, blknum, txindex, oindex, txhash, owner, currency, amount)
      end)

    outputs
  end

  defp create_output(_otype, _blknum, _txindex, _txhash, _oindex, _owner, _currency, 0), do: []

  defp create_output(otype, blknum, txindex, oindex, txhash, owner, currency, amount) when amount > 0 do
    [
      %{
        otype: otype,
        blknum: blknum,
        txindex: txindex,
        oindex: oindex,
        owner: owner,
        amount: amount,
        currency: currency,
        creating_txhash: txhash
      }
    ]
  end

  @spec create_inputs(Transaction.any_flavor_t(), binary()) :: [tuple()]
  def create_inputs(tx, spending_txhash) do
    tx
    |> Transaction.get_inputs()
    |> Enum.with_index()
    |> Enum.map(fn {Utxo.position(_, _, _) = input_utxo_pos, index} ->
      {input_utxo_pos, index, spending_txhash}
    end)
  end

  @spec get_sorted_grouped_utxos(OMG.Crypto.address_t(), order_t()) :: %{OMG.Crypto.address_t() => list(%__MODULE__{})}
  def get_sorted_grouped_utxos(owner, order \\ :desc) do
    # TODO: use clever DB query to get following out of DB
    owner
    |> get_all_utxos()
    |> Enum.group_by(fn utxo -> utxo.currency end)
    |> Enum.map(fn {currency, utxos} ->
      {currency, Enum.sort_by(utxos, fn utxo -> utxo.amount end, order)}
    end)
    |> Map.new()
  end

  defp query_get_utxos(address) do
    from(
      txoutput in __MODULE__,
      preload: [:ethevents],
      left_join: ethevent in assoc(txoutput, :ethevents),
      # select txoutputs by owner that have neither been spent nor have a corresponding ethevents exit events
      where:
        txoutput.owner == ^address and is_nil(txoutput.spending_txhash) and
          (is_nil(ethevent) or
             fragment(
               "
NOT EXISTS (SELECT 1
           FROM ethevents_txoutputs AS etfrag
           JOIN ethevents AS efrag ON
                    etfrag.root_chain_txhash_event=efrag.root_chain_txhash_event
                    AND efrag.event_type = ANY(?)
                    AND etfrag.child_chain_utxohash = ?)",
               ["standard_exit", "in_flight_exit"],
               txoutput.child_chain_utxohash
             )),
      order_by: [asc: :blknum, asc: :txindex, asc: :oindex]
    )
  end

  @spec get_all_utxos(OMG.Crypto.address_t()) :: list()
  @decorate trace(service: :ecto, type: :db, tracer: OMG.WatcherInfo.Tracer)
  defp get_all_utxos(address) do
    query = query_get_utxos(address)
    Repo.all(query)
  end
end
