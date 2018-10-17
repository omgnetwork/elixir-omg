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

defmodule OMG.Watcher.DB.Transaction do
  @moduledoc """
  Ecto Schema representing DB Transaction.
  """
  use Ecto.Schema
  use OMG.API.LoggerExt

  alias OMG.API.State.Transaction
  alias OMG.API.Utxo
  alias OMG.Watcher.DB
  alias OMG.Watcher.DB.Repo

  require Utxo

  import Ecto.Changeset
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

    has_many(:inputs, DB.TxOutput, foreign_key: :spending_txhash)
    has_many(:outputs, DB.TxOutput, foreign_key: :creating_txhash)
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

  @doc """
  Inserts complete and sorted enumberable of transactions for particular block number
  """
  @spec update_with(mined_block()) :: [{:ok, __MODULE__}]
  def update_with(%{transactions: transactions, blknum: block_number, eth_height: eth_height}) do
    # FIXME: remove time measurement & logging
    start = System.monotonic_time()

    [db_txs, db_outputs, db_inputs] =
      transactions
      |> Stream.with_index()
      |> Enum.reduce([[], [], []], fn {tx, txindex}, acc -> process(tx, block_number, txindex, eth_height, acc) end)

    prepare_dur = System.monotonic_time() - start

    start = System.monotonic_time()

    result =
      Repo.transaction(fn ->
        Repo.insert_all(__MODULE__, db_txs)
        Repo.insert_all(DB.TxOutput, db_outputs)
      end)

    # inputs are set as spent after outputs are inserted to support spending utxo from the same block
    db_inputs
    |> Enum.each(fn {utxo_pos, spending_oindex, spending_txhash} ->
      if utxo = DB.TxOutput.get_by_position(utxo_pos) do
        utxo
        |> change(spending_tx_oindex: spending_oindex, spending_txhash: spending_txhash)
        |> Repo.update!()
      end
    end)

    insert_dur = System.monotonic_time() - start

    Logger.info(fn ->
      count = Enum.count(transactions)
      prep = System.convert_time_unit(prepare_dur, :native, :millisecond)
      ins = System.convert_time_unit(insert_dur, :native, :millisecond)

      "Prepared ##{block_number} with #{count} txs in #{prep}ms\nTransaction send time #{ins}ms"
    end)

    result
  end

  # @spec process(Transaction.Recovered.t(), pos_integer(), integer(), pos_integer())
  defp process(
         %Transaction.Recovered{
           signed_tx_hash: signed_tx_hash,
           signed_tx: %Transaction.Signed{signed_tx_bytes: signed_tx_bytes, raw_tx: raw_tx = %Transaction{}}
         },
         block_number,
         txindex,
         eth_height,
         [tx_list, output_list, input_list]
       ) do
    [
      [create(block_number, txindex, signed_tx_hash, eth_height, signed_tx_bytes) | tx_list],
      DB.TxOutput.create_outputs(block_number, txindex, signed_tx_hash, raw_tx) ++ output_list,
      DB.TxOutput.create_inputs(raw_tx, signed_tx_hash) ++ input_list
    ]
  end

  @spec create(pos_integer(), integer(), binary(), pos_integer(), binary()) :: __MODULE__
  defp create(
         block_number,
         txindex,
         txhash,
         eth_height,
         txbytes
       ) do
    %{
      txhash: txhash,
      txbytes: txbytes,
      blknum: block_number,
      txindex: txindex,
      eth_height: eth_height
    }
  end

  @spec get_transaction_challenging_utxo(Utxo.Position.t()) :: {:ok, %__MODULE__{}} | {:error, :utxo_not_spent}
  def get_transaction_challenging_utxo(position) do
    # finding tx's input can be tricky
    input =
      DB.TxOutput.get_by_position(position)
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
