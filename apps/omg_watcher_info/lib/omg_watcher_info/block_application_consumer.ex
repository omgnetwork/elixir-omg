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
  Subscribes for new blocks and inserts them into a pending queue of blocks waiting to be processed.
  """
  require Logger

  use GenServer

  alias OMG.WatcherInfo.DB

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    _ = Logger.info("Started #{inspect(__MODULE__)}")

    :ok = OMG.Bus.subscribe({:child_chain, "block.get"}, link: true)

    {:ok, %{}}
  end

  # Listens for blocks and insert them to the WatcherDB.
  def handle_info({:internal_event_bus, :block_received, block_application}, state) do
    _ =
      block_application
      |> to_pending_block()
      |> DB.PendingBlock.insert()

    {:noreply, state}
  end

  defp to_pending_block(%{} = block) do
    data = %{
      eth_height: block.eth_height,
      blknum: block.number,
      blkhash: block.hash,
      timestamp: block.timestamp,
      transactions: block.transactions
    }

    %{
      data: :erlang.term_to_binary(data),
      blknum: block.number
    }
  end
end
