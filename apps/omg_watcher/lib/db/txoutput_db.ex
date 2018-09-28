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

defmodule OMG.Watcher.DB.TxOutputDB do
  @moduledoc """
  Ecto schema for transaction's output or input
  """
  use Ecto.Schema

  alias OMG.API.Block
  alias OMG.API.State.Transaction
  alias OMG.API.Utxo
  alias OMG.Watcher.DB.EthEventDB
  alias OMG.Watcher.DB.Repo
  alias OMG.Watcher.DB.TransactionDB

  require Utxo

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  schema "txoutputs" do
    field(:owner, :binary)
    field(:amount, OMG.Watcher.DB.Types.IntegerType)
    field(:currency, :binary)
    field(:proof, :binary)
    field(:creating_tx_oindex, :integer)
    field(:spending_tx_oindex, :integer)

    belongs_to(:creating_transaction, TransactionDB, foreign_key: :creating_txhash, references: :txhash, type: :binary)
    belongs_to(:deposit, EthEventDB, foreign_key: :creating_deposit, references: :hash, type: :binary)

    belongs_to(:spending_transaction, TransactionDB, foreign_key: :spending_txhash, references: :txhash, type: :binary)
    belongs_to(:exit, EthEventDB, foreign_key: :spending_exit, references: :hash, type: :binary)
  end

  def compose_utxo_exit(Utxo.position(blknum, txindex, _) = decoded_utxo_pos) do
    txs = TransactionDB.get_by_blknum(blknum)

    if Enum.any?(txs, &match?(%{txindex: ^txindex}, &1)),
      do: {:ok, compose_utxo_exit(txs, decoded_utxo_pos)},
      else: {:error, :no_tx_for_given_blknum}
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
       sig1: sig1,
       sig2: sig2
     }} = Transaction.Signed.decode(tx.txbytes)

    %{
      utxo_pos: utxo_pos,
      txbytes: Transaction.encode(raw_tx),
      proof: proof,
      sigs: sig1 <> sig2
    }
  end

  def get_all, do: Repo.all(__MODULE__)

  @spec get_by_position(Utxo.Position.t()) :: map() | nil
  def get_by_position(Utxo.position(blknum, _, _) = position) do
    # first try to find it as tx's output then deposit's output otherwise
    get_from_tx(position) || get_from_deposit(blknum)
  end

  @spec get_from_tx(Utxo.Position.t()) :: map() | nil
  defp get_from_tx(position) do
    tx = TransactionDB.get_tx_output(position)

    tx && tx.outputs |> hd()
  end

  @spec get_from_deposit(pos_integer()) :: map() | nil
  defp get_from_deposit(blknum) do
    query =
      from(
        evnt in EthEventDB,
        where: evnt.deposit_blknum == ^blknum and evnt.deposit_txindex == 0 and evnt.event_type == ^:deposit,
        preload: [:created_utxo]
      )

    deposit = Repo.one(query)
    deposit && deposit.created_utxo
  end

  def get_utxos(owner) do
    query =
      from(
        txo in __MODULE__,
        where: txo.owner == ^owner and is_nil(txo.spending_txhash) and is_nil(txo.spending_exit),
        preload: [:creating_transaction, :deposit]
      )

    Repo.all(query)
  end

  def get_balance(owner) do
    query =
      from(t in __MODULE__,
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

  def create_outputs(%Transaction{
        cur12: cur12,
        newowner1: newowner1,
        amount1: amount1,
        newowner2: newowner2,
        amount2: amount2
      }) do
    # zero-value outputs are not inserted, but there have to be at least one
    # TODO: can tx have no outputs?
    [_output | _] = create_output(newowner1, cur12, amount1, 0) ++ create_output(newowner2, cur12, amount2, 1)
  end

  defp create_output(_owner, _currency, 0, _position), do: []

  defp create_output(owner, currency, amount, index) when amount > 0,
    do: [%__MODULE__{owner: owner, amount: amount, currency: currency, creating_tx_oindex: index}]

  def get_inputs(%Transaction{
        blknum1: blknum1,
        txindex1: txindex1,
        oindex1: oindex1,
        blknum2: blknum2,
        txindex2: txindex2,
        oindex2: oindex2
      }) do
    [
      get_by_position(Utxo.position(blknum1, txindex1, oindex1)),
      get_by_position(Utxo.position(blknum2, txindex2, oindex2))
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.with_index()
    |> Enum.map(fn {input, index} ->
      change(input, spending_tx_oindex: index)
    end)
  end
end
