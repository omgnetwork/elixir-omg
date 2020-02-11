# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule OMG.WatcherInfo.BlockApplicationConsumer do
  @moduledoc """
  Subscribes for new blocks and inserts them to WatcherInfo.DB.
  """
  alias OMG.WatcherInfo.DB
  require Logger

  ### Client

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  ### Server

  use GenServer

  def init(:ok) do
    :ok = OMG.Bus.subscribe("block.get", link: true)

    _ = Logger.info("Started #{inspect(__MODULE__)}")
    {:ok, %{}}
  end

  # Listens for blocks and insert them to the WatcherDB.
  def handle_info({:internal_event_bus, :block_received, block_application}, state) do
    _ =
      block_application
      |> to_mined_block()
      |> DB.Block.insert_with_transactions()

    {:noreply, state}
  end

  defp to_mined_block(%{} = block) do
    %{
      eth_height: block.eth_height,
      blknum: block.number,
      blkhash: block.hash,
      timestamp: block.timestamp,
      transactions: block.transactions
    }
  end
end
