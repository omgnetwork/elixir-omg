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

defmodule OMG.WatcherInfo.DB.TxOutput do
  @moduledoc """
  Ecto schema for transaction's output or input
  """
  import Ecto.Query

  use Ecto.Schema

  alias OMG.Crypto
  alias OMG.State.Transaction
  alias OMG.Utxo
  alias OMG.WatcherInfo.DB
  alias OMG.WatcherInfo.DB.Repo

  require Utxo

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

  @primary_key false
  schema "txoutputs" do
    field(:blknum, :integer, primary_key: true)
    field(:txindex, :integer, primary_key: true)
    field(:oindex, :integer, primary_key: true)
    field(:owner, :binary)
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
      join_through: DB.EthEventsTxOutputs,
      join_keys: [child_chain_utxohash: :child_chain_utxohash, root_chain_txhash_event: :root_chain_txhash_event]
    )

    timestamps(type: :utc_datetime_usec)
  end

  def fetch_by(where_conditions) do
    DB.Repo.fetch(
      from(txoutputs in __MODULE__,
        left_join: ethevents in assoc(txoutput, :ethevents),
        left_join: creating_transaction in assoc(txoutput, :creating_transaction),
        left_join: spending_transaction in assoc(txoutput, :spending_transaction),
        preload: [
          ethevents: ethevents,
          creating_transaction: creating_transaction,
          spending_transaction: spending_transaction
        ],
        where: ^where_conditions,
        order_by: [asc: txoutputs.blknum, asc: txoutputs.txindex, asc: txoutputs.oindex]
      )
    )
  end

  @spec get_by_position(Utxo.Position.t()) :: map() | nil
  def get_by_position(Utxo.position(blknum, txindex, oindex)) do
    Repo.one(
      from(txoutput in __MODULE__,
        left_join: ethevents in assoc(txoutput, :ethevents),
        left_join: creating_transaction in assoc(txoutput, :creating_transaction),
        left_join: spending_transaction in assoc(txoutput, :spending_transaction),
        preload: [
          ethevents: ethevents,
          creating_transaction: creating_transaction,
          spending_transaction: spending_transaction
        ],
        where: txoutput.blknum == ^blknum and txoutput.txindex == ^txindex and txoutput.oindex == ^oindex
      )
    )
  end

  # same as get_by_position, except this function only returns unspent txoutputs
  @spec get_utxo_by_position(Utxo.Position.t()) :: %__MODULE__{} | nil
  def get_utxo_by_position(Utxo.position(blknum, txindex, oindex)) do
    Repo.one(
      from(
        txoutput in __MODULE__,
        left_join: ethevents in assoc(txoutput, :ethevents),
        left_join: creating_transaction in assoc(txoutput, :creating_transaction),
        left_join: spending_transaction in assoc(txoutput, :spending_transaction),
        preload: [:ethevents, :creating_transaction, :spending_transaction],
        where: ^filter_where_unspent(blknum: blknum, txindex: txindex, oindex: oindex)
      )
    )
  end

  def get_utxos(owner) do
    query =
      from(
        txoutput in __MODULE__,
        left_join: ethevents in assoc(txoutput, :ethevents),
        left_join: creating_transaction in assoc(txoutput, :creating_transaction),
        left_join: spending_transaction in assoc(txoutput, :spending_transaction),
        preload: [:ethevents, :creating_transaction, :spending_transaction],
        where: ^filter_where_unspent(owner: owner),
        order_by: [asc: :blknum, asc: :txindex, asc: :oindex]
      )

    Repo.all(query)
  end

  @spec get_balance(OMG.Crypto.address_t()) :: list(balance())
  def get_balance(owner) do
    query =
      from(
        txoutput in __MODULE__,
        where: ^filter_where_unspent(owner: owner),
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

  @spec spend_utxos([map()]) :: :ok
  def spend_utxos(db_inputs) do
    utc_now = DateTime.utc_now()

    db_inputs
    |> Enum.each(fn {Utxo.position(blknum, txindex, oindex), spending_oindex, spending_txhash} ->
      _ =
        DB.TxOutput
        |> where(blknum: ^blknum, txindex: ^txindex, oindex: ^oindex)
        |> Repo.update_all(
          set: [spending_tx_oindex: spending_oindex, spending_txhash: spending_txhash, updated_at: utc_now]
        )
    end)
  end

  @spec create_outputs(pos_integer(), integer(), binary(), Transaction.any_flavor_t()) :: [map()]
  def create_outputs(
        blknum,
        txindex,
        txhash,
        tx
      ) do
    # zero-value outputs are not inserted, tx can have no outputs at all
    outputs =
      tx
      |> Transaction.get_outputs()
      |> Enum.with_index()
      |> Enum.flat_map(fn {%{currency: currency, owner: owner, amount: amount}, oindex} ->
        create_output(blknum, txindex, oindex, txhash, owner, currency, amount)
      end)

    outputs
  end

  defp create_output(_blknum, _txindex, _txhash, _oindex, _owner, _currency, 0), do: []

  defp create_output(blknum, txindex, oindex, txhash, owner, currency, amount) when amount > 0,
    do: [
      %{
        blknum: blknum,
        txindex: txindex,
        oindex: oindex,
        owner: owner,
        amount: amount,
        currency: currency,
        creating_txhash: txhash
      }
    ]

  @spec create_inputs(Transaction.any_flavor_t(), binary()) :: [tuple()]
  def create_inputs(tx, spending_txhash) do
    tx
    |> Transaction.get_inputs()
    |> Enum.with_index()
    |> Enum.map(fn {Utxo.position(_, _, _) = input_utxo_pos, index} ->
      {input_utxo_pos, index, spending_txhash}
    end)
  end

  @spec get_sorted_grouped_utxos(OMG.Crypto.address_t()) :: %{OMG.Crypto.address_t() => list(%__MODULE__{})}
  def get_sorted_grouped_utxos(owner) do
    # TODO: use clever DB query to get following out of DB
    get_utxos(owner)
    |> Enum.group_by(& &1.currency)
    |> Enum.map(fn {k, v} -> {k, Enum.sort_by(v, & &1.amount, &>=/2)} end)
    |> Map.new()
  end

  def new_changeset(%{blknum: blknum, owner: owner, currency: currency, amount: amount}) do
    txoutput = %{
      child_chain_utxohash: DB.TxOutput.generate_child_chain_utxohash(Utxo.position(blknum, 0, 0)),
      blknum: blknum,
      txindex: 0,
      oindex: 0,
      owner: owner,
      currency: currency,
      amount: amount,
      creating_txhash: nil,
      spending_txhash: nil,
      spending_tx_oindex: nil,
      proof: nil
    }

    changeset(%__MODULE__{}, txoutput)
  end

  @doc false
  def changeset(struct, params \\ %{}) do
    fields = [
      :child_chain_utxohash,
      :blknum,
      :txindex,
      :oindex,
      :owner,
      :currency,
      :amount,
      :creating_txhash,
      :spending_txhash,
      :spending_tx_oindex,
      :proof
    ]

    required_fields = [:blknum, :txindex, :oindex, :child_chain_utxohash, :owner, :amount, :currency]

    struct
    |> Ecto.Changeset.cast(params, fields)
    |> Ecto.Changeset.validate_required(required_fields)
    |> Ecto.Changeset.unique_constraint(:blknum, name: :txoutputs_pkey)
    |> Ecto.Changeset.unique_constraint(:child_chain_utxohash)
  end
end
