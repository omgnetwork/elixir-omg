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

defmodule OMG.Watcher.DB.TransactionDB do
  @moduledoc """
  Ecto Schema representing TransactionDB.
  """
  use Ecto.Schema

  alias OMG.API.State.{Transaction, Transaction.Recovered, Transaction.Signed}
  alias OMG.API.Utxo
  alias OMG.Watcher.DB.Repo
  alias OMG.Watcher.DB.TxOutputDB

  require Utxo

  import Ecto.Query, only: [from: 2]

  @type mined_block() :: %{
    transactions: [OMG.API.State.Transaction.Recovered.t()],
    blknum: pos_integer(),
    eth_height: pos_integer()
  }

  @primary_key {:txhash, :binary, []}
  @derive {Phoenix.Param, key: :txhash}
  @derive {Poison.Encoder, except: [:__meta__]}
  schema "transactions" do
    field(:blknum, :integer)
    field(:txindex, :integer)
    field(:txbytes, :binary)
    field(:sent_at, :utc_datetime)
    field(:eth_height, :integer)

    has_many(:inputs, TxOutputDB, foreign_key: :spending_txhash)
    has_many(:outputs, TxOutputDB, foreign_key: :creating_txhash)
  end

  def get(hash) do
    __MODULE__
    |> Repo.get(hash)
  end

  def get_by_blknum(blknum) do
    Repo.all(from(__MODULE__, where: [blknum: ^blknum]))
  end

  def get_by_position(blknum, txindex) do
    Repo.one(from(__MODULE__, where: [blknum: ^blknum, txindex: ^txindex]))
  end

  @spec get_tx_output(Utxo.Position.t()) :: map() | nil
  def get_tx_output(Utxo.position(blknum, txindex, oindex)) do
    query =
      from(
        t in __MODULE__,
        join: o in assoc(t, :outputs),
        where: t.blknum == ^blknum and t.txindex == ^txindex and o.creating_tx_oindex == ^oindex,
        preload: [outputs: o]
      )

    Repo.one(query)
  end

  @doc """
  Inserts complete and sorted enumberable of transactions for particular block number
  """
  @spec update_with(mined_block()) :: [{:ok, __MODULE__}]
  def update_with(%{transactions: transactions, blknum: block_number, eth_height: eth_height}) do
    transactions
    |> Stream.with_index()
    |> Enum.map(fn {tx, txindex} -> insert(tx, block_number, txindex, eth_height) end)
  end

  @spec insert(Recovered.t(), pos_integer(), integer(), pos_integer()) :: {:ok, __MODULE__}
  def insert(
        %Recovered{
          signed_tx_hash: signed_tx_hash,
          signed_tx:
            %Signed{
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
        inputs: TxOutputDB.get_inputs(raw_tx),
        outputs: TxOutputDB.create_outputs(raw_tx)
      }
      |> Repo.insert()
  end

  @spec get_transaction_challenging_utxo(Utxo.Position.t()) :: {:ok, %__MODULE__{}} | {:error, :utxo_not_spent}
  def get_transaction_challenging_utxo(position) do
    # finding tx's input can be tricky
    input =
      TxOutputDB.get_by_position(position)
      |> Repo.preload([:spending_transaction])

    case input && input.spending_transaction do
      nil ->
        {:error, :utxo_not_spent}

      tx ->
        # transaction which spends output specified by position with outputs it created
        tx = %__MODULE__{(tx |> Repo.preload([:outputs])) | inputs: [input]}

        {:ok, tx}
    end
  end
end
