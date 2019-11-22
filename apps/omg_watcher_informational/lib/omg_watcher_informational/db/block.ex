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

defmodule OMG.WatcherInformational.DB.Block do
  @moduledoc """
  Ecto schema for Plasma Chain block
  """
  use Ecto.Schema
  use OMG.Utils.LoggerExt

  alias OMG.State
  alias OMG.WatcherInformational.DB

  @type mined_block() :: %{
          transactions: [State.Transaction.Recovered.t()],
          blknum: pos_integer(),
          blkhash: <<_::256>>,
          timestamp: pos_integer(),
          eth_height: pos_integer()
        }

  @primary_key {:blknum, :integer, []}
  @derive {Phoenix.Param, key: :blknum}
  schema "blocks" do
    field(:hash, :binary)
    field(:eth_height, :integer)
    field(:timestamp, :integer)
  end

  def get_max_blknum do
    DB.Repo.aggregate(__MODULE__, :max, :blknum)
  end

  @doc """
  Inserts complete and sorted enumerable of transactions for particular block number
  """
  @spec insert_with_transactions(mined_block()) :: {:ok, %__MODULE__{}}
  def insert_with_transactions(%{
        transactions: transactions,
        blknum: block_number,
        blkhash: blkhash,
        timestamp: timestamp,
        eth_height: eth_height
      }) do
    [db_txs, db_outputs, db_inputs] =
      transactions
      |> Stream.with_index()
      |> Enum.reduce([[], [], []], fn {tx, txindex}, acc -> process(tx, block_number, txindex, acc) end)

    current_block = %DB.Block{blknum: block_number, hash: blkhash, timestamp: timestamp, eth_height: eth_height}

    {insert_duration, {:ok, _} = result} =
      :timer.tc(
        &DB.Repo.transaction/1,
        [
          fn ->
            {:ok, _} = DB.Repo.insert(current_block)
            _ = DB.Repo.insert_all_chunked(DB.Transaction, db_txs)
            _ = DB.Repo.insert_all_chunked(DB.TxOutput, db_outputs)

            # inputs are set as spent after outputs are inserted to support spending utxo from the same block
            DB.TxOutput.spend_utxos(db_inputs)
          end
        ]
      )

    _ = Logger.debug("Block \##{block_number} persisted in WatcherDB, done in #{insert_duration / 1000}ms")

    result
  end

  @spec process(State.Transaction.Recovered.t(), pos_integer(), integer(), list()) :: [list()]
  defp process(
         %State.Transaction.Recovered{
           signed_tx: %State.Transaction.Signed{raw_tx: %State.Transaction.Payment{metadata: metadata}} = tx,
           signed_tx_bytes: signed_tx_bytes
         },
         block_number,
         txindex,
         [tx_list, output_list, input_list]
       ) do
    tx_hash = State.Transaction.raw_txhash(tx)

    [
      [create(block_number, txindex, tx_hash, signed_tx_bytes, metadata) | tx_list],
      DB.TxOutput.create_outputs(block_number, txindex, tx_hash, tx) ++ output_list,
      DB.TxOutput.create_inputs(tx, tx_hash) ++ input_list
    ]
  end

  @spec create(pos_integer(), integer(), binary(), binary(), State.Transaction.metadata()) ::
          map()
  defp create(
         block_number,
         txindex,
         txhash,
         txbytes,
         metadata
       ) do
    %{
      txhash: txhash,
      txbytes: txbytes,
      blknum: block_number,
      txindex: txindex,
      metadata: metadata
    }
  end
end
