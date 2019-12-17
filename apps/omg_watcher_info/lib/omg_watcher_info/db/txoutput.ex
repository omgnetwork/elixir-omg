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
  import Ecto.Query, only: [from: 2]

  use Ecto.Schema

  alias OMG.State.Transaction
  alias OMG.WatcherInfo.DB
  alias OMG.WatcherInfo.DB.Repo

  import Ecto.Query, only: [from: 2, where: 2]

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
      join_through: "ethevents_txoutputs",
      join_keys: [child_chain_utxohash: :child_chain_utxohash, root_chain_txhash_event: :root_chain_txhash_event]
    )

    timestamps(type: :utc_datetime)
  end

  # preload ethevents in a single query as there will not be a large number of them
  @spec get_by_position(OMG.InputPointer.utxo_pos_tuple()) :: map() | nil
  def get_by_position({:utxo_position, blknum, txindex, oindex}) do
    DB.Repo.one(
      from(txoutput in __MODULE__,
        preload: [:ethevents],
        left_join: ethevent in assoc(txoutput, :ethevents),
        where: txoutput.blknum == ^blknum and txoutput.txindex == ^txindex and txoutput.oindex == ^oindex
      )
    )
  end

  def get_utxos(owner) do
    query =
      from(
        txoutput in __MODULE__,
        preload: [:ethevents],
        left_join: ethevent in assoc(txoutput, :ethevents),
        # select txoutputs by owner that have neither been spent nor have a corresponding ethevents exit events
        where: txoutput.owner == ^owner and is_nil(txoutput.spending_txhash) and (is_nil(ethevent) or fragment("
 NOT EXISTS (SELECT 1
             FROM ethevents_txoutputs AS etfrag
             JOIN ethevents AS efrag ON
                      etfrag.root_chain_txhash_event=efrag.root_chain_txhash_event
                      AND efrag.event_type IN (?)
                      AND etfrag.child_chain_utxohash = ?)", "standard_exit", txoutput.child_chain_utxohash)),
        order_by: [asc: :blknum, asc: :txindex, asc: :oindex]
      )

    Repo.all(query)
  end

  @spec get_balance(OMG.Crypto.address_t()) :: list(balance())
  def get_balance(owner) do
    query =
      from(
        txoutput in __MODULE__,
        left_join: ethevent in assoc(txoutput, :ethevents),
        # select txoutputs by owner that have neither been spent nor have a corresponding ethevents exit events
        where: txoutput.owner == ^owner and is_nil(txoutput.spending_txhash) and (is_nil(ethevent) or fragment("
 NOT EXISTS (SELECT 1
             FROM ethevents_txoutputs AS etfrag
             JOIN ethevents AS efrag ON
                      etfrag.root_chain_txhash_event=efrag.root_chain_txhash_event
                      AND efrag.event_type IN (?)
                      AND etfrag.child_chain_utxohash = ?)", "standard_exit", txoutput.child_chain_utxohash)),
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
    db_inputs
    |> Enum.each(fn {{:utxo_position, blknum, txindex, oindex}, spending_oindex, spending_txhash} ->
      _ =
        DB.TxOutput
        |> where(blknum: ^blknum, txindex: ^txindex, oindex: ^oindex)
        |> Repo.update_all(set: [spending_tx_oindex: spending_oindex, spending_txhash: spending_txhash])
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
    |> Enum.map(fn {{:utxo_position, _, _, _} = input_utxo_pos, index} ->
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
end
