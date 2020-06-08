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

defmodule OMG.WatcherInfo.PendingBlockProcessor do
  @moduledoc """
  This module is in charge of processing the queue of pending blocks that are waiting to
  be inserted in the database.
  It internally relies on a timer that will check the queue state at every iteration and
  will process pending blocks one by one until the queue is empty.
  """

  require Logger

  use GenServer

  alias OMG.WatcherInfo.PendingBlockProcessor.Storage

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: Keyword.get(args, :name, __MODULE__))
  end

  def init(args) do
    interval = Keyword.fetch!(args, :processing_interval)
    storage_module = Keyword.get(args, :storage_module, Storage)
    _ = Logger.info("Started #{inspect(__MODULE__)}")
    {:ok, %{interval: interval, block: nil, storage_module: storage_module}, interval}
  end

  def handle_info(:timeout, state) do
    block = state.storage_module.get_next_pending_block()
    {:noreply, %{state | block: block}, {:continue, :process_block}}
  end

  def handle_continue(:process_block, %{block: nil} = state) do
    {:noreply, state, state.interval}
  end

  def handle_continue(:process_block, %{block: block} = state) do
    state.storage_module.process_block(block)

    {:noreply, %{state | block: nil}, 1}
  end

  def terminate({%DBConnection.ConnectionError{}, _}, %{block: block} = state) when not is_nil(block) do
    # TODO: raise an alarm?
    Logger.error("insertion of block number #{block.blknum} timed out")
    {:ok, _} = state.storage_module.increment_retry_count(block)
    :ok
  end

  def terminate(_, _), do: :ok
end
