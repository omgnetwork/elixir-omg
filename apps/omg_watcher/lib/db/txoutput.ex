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

defmodule OMG.Watcher.DB.TxOutput do
  @moduledoc """
  Ecto schema for transaction's output or input
  """
  use Ecto.Schema

  alias OMG.API.Block
  alias OMG.API.State.Transaction
  alias OMG.API.Utxo
  alias OMG.Watcher.DB
  alias OMG.Watcher.DB.Repo

  require Utxo

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

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
    field(:amount, OMG.Watcher.DB.Types.IntegerType)
    field(:currency, :binary)
    field(:proof, :binary)
    field(:spending_tx_oindex, :integer)

    belongs_to(:creating_transaction, DB.Transaction, foreign_key: :creating_txhash, references: :txhash, type: :binary)
    belongs_to(:deposit, DB.EthEvent, foreign_key: :creating_deposit, references: :hash, type: :binary)

    belongs_to(:spending_transaction, DB.Transaction, foreign_key: :spending_txhash, references: :txhash, type: :binary)
    belongs_to(:exit, DB.EthEvent, foreign_key: :spending_exit, references: :hash, type: :binary)
  end

  @spec compose_utxo_exit(Utxo.Position.t()) :: {:ok, exit_t()} | {:error, :utxo_not_found}
  def compose_utxo_exit(Utxo.position(blknum, txindex, _) = decoded_utxo_pos) do
    txs = DB.Transaction.get_by_blknum(blknum)

    if Enum.any?(txs, &match?(%{txindex: ^txindex}, &1)),
      do: {:ok, compose_utxo_exit(txs, decoded_utxo_pos)},
      else: {:error, :utxo_not_found}
  end

  def compose_utxo_exit(txs, Utxo.position(_blknum, txindex, _) = decoded_utxo_pos) do
    sorted_txs = Enum.sort_by(txs, & &1.txindex)
    txs_hashes = Enum.map(sorted_txs, & &1.txhash)
    proof = Block.create_tx_proof(txs_hashes, txindex)
    tx = Enum.at(sorted_txs, txindex)

    utxo_pos = decoded_utxo_pos |> Utxo.Position.encode()

    {:ok,
     %Transaction.Signed{
       raw_tx: raw_tx,
       sigs: sigs
     }} = Transaction.Signed.decode(tx.txbytes)

    sigs = Enum.join(sigs)

    %{
      utxo_pos: utxo_pos,
      txbytes: Transaction.encode(raw_tx),
      proof: proof,
      sigs: sigs
    }
  end

  def get_all, do: Repo.all(__MODULE__)

  @spec get_by_position(Utxo.Position.t()) :: map() | nil
  def get_by_position(Utxo.position(blknum, txindex, oindex)) do
    Repo.get_by(__MODULE__, blknum: blknum, txindex: txindex, oindex: oindex)
  end

  def get_utxos(owner) do
    query =
      from(
        txo in __MODULE__,
        where: txo.owner == ^owner and is_nil(txo.spending_txhash) and is_nil(txo.spending_exit),
        order_by: [asc: :blknum, asc: :txindex, asc: :oindex],
        preload: [:creating_transaction, :deposit]
      )

    Repo.all(query)
  end

  @spec get_balance(OMG.API.Crypto.address_t()) :: list(balance())
  def get_balance(owner) do
    query =
      from(
        t in __MODULE__,
        where: t.owner == ^owner and is_nil(t.spending_txhash) and is_nil(t.spending_exit),
        group_by: t.currency,
        select: {t.currency, sum(t.amount)}
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
    |> Enum.each(fn {utxo_pos, spending_oindex, spending_txhash} ->
      if utxo = DB.TxOutput.get_by_position(utxo_pos) do
        utxo
        |> change(spending_tx_oindex: spending_oindex, spending_txhash: spending_txhash)
        |> Repo.update!()
      end
    end)
  end

  @spec create_outputs(pos_integer(), integer(), binary(), %Transaction{}) :: [map()]
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

  @spec create_inputs(%Transaction{}, binary()) :: [tuple()]
  def create_inputs(%Transaction{inputs: inputs}, spending_txhash) do
    inputs
    |> Enum.with_index()
    |> Enum.map(fn {%{blknum: blknum, txindex: txindex, oindex: oindex}, index} ->
      {Utxo.position(blknum, txindex, oindex), index, spending_txhash}
    end)
  end
end
