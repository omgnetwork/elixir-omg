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

defmodule OMG.Watcher.TransactionDB do
  @moduledoc """
  Ecto Schema representing TransactionDB.
  """
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  alias OMG.API.State.{Transaction, Transaction.Recovered, Transaction.Signed}
  alias OMG.API.Utxo
  require Utxo
  alias OMG.Watcher.Repo
  alias OMG.Watcher.TxOutputDB

  @field_names [
    :txhash,
    :blknum,
    :txindex,
    :txbytes,
    :sent_at,
    :eth_height
  ]
  def field_names, do: @field_names

  @primary_key {:txhash, :binary, []}
  @derive {Phoenix.Param, key: :txhash}
  @derive {Poison.Encoder, except: [:__meta__]}
  schema "transactions" do
    field :blknum, :integer
    field :txindex, :integer
    field :txbytes, :binary
    field :sent_at, :utc_datetime
    field :eth_height, :integer

    has_many :inputs, TxOutputDB, foreign_key: :spending_txhash
    has_many :outputs, TxOutputDB, foreign_key: :creating_txhash
  end

  def get(hash) do
    __MODULE__
    |> Repo.get(hash)
  end

  def find_by_blknum(blknum) do
    # FIXME: rewrite query find_by_blknum
    Repo.all(from(tr in __MODULE__, where: tr.blknum == ^blknum, select: tr))
  end

  @doc """
  Inserts complete and sorted enumberable of transactions for particular block number
  """
  def update_with(%{transactions: transactions, number: block_number, eth_height: eth_height}) do
    transactions
    |> Stream.with_index()
    |> Enum.map(fn {tx, txindex} -> insert(tx, block_number, txindex, eth_height) end)
  end

  def insert(
    %Recovered{
      signed_tx_hash: signed_tx_hash,
      signed_tx: %Signed{
        raw_tx: raw_tx = %Transaction{}
      } = signed_tx
    },
    block_number,
    txindex,
    eth_height
  ) do
    {:ok, _} =
      %__MODULE__{
        txhash: signed_tx_hash,
        txbytes: signed_tx.signed_tx_bytes,
        blknum: block_number,
        txindex: txindex,
        eth_height: eth_height,
        outputs: TxOutputDB.create_outputs(raw_tx)
      }
    # FIXME: Add inputs & outputs
    |> Repo.insert()
  end

  def changeset(transaction_db, attrs) do
    transaction_db
    |> cast(attrs, @field_names)
    |> validate_required(@field_names)
    |> unique_constraint(:tx_plasma_position, name: :unq_transaction_blknum_txindex)
  end

  @spec get_transaction_challenging_utxo(Utxo.Position.t()) :: {:ok, map()} | {:error, :utxo_not_spent}
  def get_transaction_challenging_utxo(Utxo.position(blknum, txindex, oindex)) do
    # FIXME: rewrite query get_transaction_challenging_utxo
    query =
      from(
        tx_db in __MODULE__,
        where:
          (tx_db.blknum1 == ^blknum and tx_db.txindex1 == ^txindex and tx_db.oindex1 == ^oindex) or
            (tx_db.blknum2 == ^blknum and tx_db.txindex2 == ^txindex and tx_db.oindex2 == ^oindex)
      )

    txs = Repo.all(query)

    case txs do
      [] -> {:error, :utxo_not_spent}
      [tx] -> {:ok, tx}
    end
  end
end
