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

defmodule OMG.Watcher.UtxoDB do
  @moduledoc """
  Ecto schema for utxo
  """
  use Ecto.Schema

  alias OMG.API.{Block, Crypto}
  alias OMG.API.State.{Transaction, Transaction.Recovered, Transaction.Signed}
  alias OMG.API.Utxo
  require Utxo
  alias OMG.Watcher.Repo
  alias OMG.Watcher.TransactionDB

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  @field_names [:address, :currency, :amount, :blknum, :txindex, :oindex, :txbytes]
  def field_names, do: @field_names

  schema "utxos" do
    field(:address, :binary)
    field(:currency, :binary)
    field(:amount, :integer)
    field(:blknum, :integer)
    field(:txindex, :integer)
    field(:oindex, :integer)
    field(:txbytes, :binary)
  end

  defp consume_transaction(
         %Signed{raw_tx: %Transaction{} = transaction, signed_tx_bytes: signed_tx_bytes},
         txindex,
         block_number
       ) do
    make_utxo_db = fn transaction, number ->
      # essentially number - 1 but to be extra safe let's limit the possible inputs according to the
      # current tx format
      new_oindex =
        case number do
          1 -> 0
          2 -> 1
        end

      %__MODULE__{
        address: Map.get(transaction, String.to_existing_atom("newowner#{number}")),
        currency: Map.get(transaction, :cur12),
        amount: Map.get(transaction, String.to_existing_atom("amount#{number}")),
        blknum: block_number,
        txindex: txindex,
        oindex: new_oindex,
        txbytes: signed_tx_bytes
      }
    end

    {Repo.insert(make_utxo_db.(transaction, 1)), Repo.insert(make_utxo_db.(transaction, 2))}
  end

  defp remove_utxo(%Signed{raw_tx: %Transaction{} = transaction}) do
    remove_from = fn transaction, number ->
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
    deposits
    |> Enum.each(fn deposit ->
      Repo.insert(%__MODULE__{
        address: deposit.owner,
        currency: deposit.currency,
        amount: deposit.amount,
        blknum: deposit.block_height,
        txindex: 0,
        oindex: 0,
        txbytes: <<>>
      })
    end)
  end

  def compose_utxo_exit(Utxo.position(blknum, txindex, _) = decoded_utxo_pos) do
    txs = TransactionDB.find_by_txblknum(blknum)

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

  def get_utxos(address) do
    utxos = Repo.all(from(tr in __MODULE__, where: tr.address == ^address, select: tr))
    fields_names = List.delete(@field_names, :address)
    Enum.map(utxos, &Map.take(&1, fields_names))
  end

  @doc false
  def changeset(utxo_db, attrs) do
    utxo_db
    |> cast(attrs, @field_names)
    |> validate_required(@field_names)
  end
end
