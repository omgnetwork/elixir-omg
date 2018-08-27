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

defmodule OMG.Watcher.TxOutputDB do
  @moduledoc """
  Ecto schema for transaction's output (or input)
  """
  use Ecto.Schema

  alias OMG.API.{Block, Crypto}
  alias OMG.API.State.{Transaction, Transaction.Recovered, Transaction.Signed}
  alias OMG.API.Utxo
  require Utxo
  alias OMG.Watcher.Repo
  alias OMG.Watcher.TransactionDB
  alias OMG.Watcher.EthEventDB

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  @field_names [:owner, :amount, :currency, :proof]
  def field_names, do: @field_names

  schema "txoutputs" do
    field :owner, :binary
    field :amount, OMG.Watcher.Types.IntegerType
    field :currency, :binary
    field :proof, :binary
    field :creating_tx_oindex, :integer
    field :spending_tx_oindex, :integer

    belongs_to :creating_transaction, TransactionDB, foreign_key: :creating_txhash, references: :txhash, type: :binary
    belongs_to :deposit, EthEventDB, foreign_key: :creating_deposit, references: :hash, type: :binary

    belongs_to :spending_transaction, TransactionDB, foreign_key: :spending_txhash, references: :txhash, type: :binary
    belongs_to :exit, EthEventDB, foreign_key: :spending_exit, references: :hash, type: :binary
  end

  defp consume_transaction(
         %Signed{raw_tx: %Transaction{} = transaction, signed_tx_bytes: signed_tx_bytes},
         txindex,
         block_number
       ) do
    # FIXME: Check fields
    make_utxo_db = fn transaction, number ->
      %__MODULE__{
        currency: Map.get(transaction, :cur12),
      }
    end

    {Repo.insert(make_utxo_db.(transaction, 1)), Repo.insert(make_utxo_db.(transaction, 2))}
  end

  defp remove_utxo(%Signed{raw_tx: %Transaction{} = transaction}) do
    remove_from = fn transaction, number ->
      # FIXME: rewrite
      blknum = Map.get(transaction, String.to_existing_atom("blknum#{number}"))
      txindex = Map.get(transaction, String.to_existing_atom("txindex#{number}"))
      oindex = Map.get(transaction, String.to_existing_atom("oindex#{number}"))

      elements_to_remove =
        from(
          utxoDb in __MODULE__,
          where: utxoDb.blknum == ^blknum and utxoDb.txindex == ^txindex and utxoDb.oindex == ^oindex
        )

      elements_to_remove |> Repo.delete_all()
    end

    {remove_from.(transaction, 1), remove_from.(transaction, 2)}
  end

  def update_with(%{transactions: transactions, number: block_number}) do
    numbered_transactions = Stream.with_index(transactions)

    numbered_transactions
    |> Enum.map(fn {%Recovered{signed_tx: signed}, txindex} ->
      {remove_utxo(signed), consume_transaction(signed, txindex, block_number)}
    end)
  end

  @spec insert_deposits([
          %{
            owner: Crypto.address_t(),
            currency: Crypto.address_t(),
            amount: non_neg_integer(),
            block_height: pos_integer()
          }
        ]) :: :ok
  def insert_deposits(deposits) do

    #FIXME: Add deposit EthEvent blknum: deposit.block_height, txindex: 0,

    deposits
    |> Enum.each(fn deposit ->
      Repo.insert(%__MODULE__{
        owner: deposit.owner,
        currency: deposit.currency,
        amount: deposit.amount,
        creating_tx_oindex: 0
      })
    end)
  end

  def compose_utxo_exit(Utxo.position(blknum, txindex, _) = decoded_utxo_pos) do
    txs = TransactionDB.find_by_blknum(blknum)

    case Enum.any?(txs, fn tx -> tx.txindex == txindex end) do
      false -> {:error, :no_tx_for_given_blknum}
      true -> {:ok, compose_utxo_exit(txs, decoded_utxo_pos)}
    end
  end

  def compose_utxo_exit(txs, Utxo.position(_blknum, txindex, _) = decoded_utxo_pos) do
    sorted_txs = Enum.sort_by(txs, & &1.txindex)
    hashed_txs = Enum.map_every(sorted_txs, 1, fn tx -> tx.txid end)
    proof = Block.create_tx_proof(hashed_txs, txindex)
    tx = Enum.at(sorted_txs, txindex)

    utxo_pos = decoded_utxo_pos |> Utxo.Position.encode()

    %{
      utxo_pos: utxo_pos,
      txbytes: Transaction.encode(tx),
      proof: proof,
      sigs: tx.sig1 <> tx.sig2
    }
  end

  def get_all, do: Repo.all(__MODULE__)

  def get_utxo(owner) do
    # FIXME: rewrite
    # utxos = Repo.all(from(tr in __MODULE__, where: tr.address == ^address, select: tr))
    # fields_names = List.delete(@field_names, :address)
    # Enum.map(utxos, &Map.take(&1, fields_names))
    # FIXME: get_utxo(address)
    []
  end

  def create_outputs(%Transaction{
      cur12: cur12,
      newowner1: newowner1,
      amount1: amount1,
      newowner2: newowner2,
      amount2: amount2
    }) do
    [
      %__MODULE__{owner: newowner1, amount: amount1, currency: cur12},
      %__MODULE__{owner: newowner2, amount: amount2, currency: cur12}
    ]
  end

  @doc false
  def changeset(utxo_db, attrs) do
    utxo_db
    |> cast(attrs, @field_names)
    |> validate_required(@field_names)
  end
end
