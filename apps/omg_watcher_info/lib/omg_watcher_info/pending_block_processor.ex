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
  """

  require Logger

  use GenServer

  alias OMG.WatcherInfo.DB.Block
  alias OMG.WatcherInfo.DB.PendingBlock

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    interval = Keyword.fetch!(args, :processing_interval)
    {:ok, processing_timer} = :timer.send_interval(interval, self(), :check_queue)

    _ = Logger.info("Started #{inspect(__MODULE__)}")
    {:ok, %{processing_timer: processing_timer, status: :idle}}
  end

  def handle_info(:check_queue, %{status: :processing} = state), do: {:noreply, state}

  def handle_info(:check_queue, state) do
    case PendingBlock.get_next_to_process() do
      nil ->
        {:noreply, state}

      block ->
        {:noreply, %{state | status: :processing}, {:continue, {:process_block, block}}}
    end
  end

  def handle_continue({:process_block, block}, state) do
    case Block.insert_pending_block(block) do
      {:ok, _} ->
        :ok

      {:error, _} ->
        handle_insert_error(block)
    end

    {:noreply, %{state | status: :idle}}
  end

  defp handle_insert_error(%{retry_count: count} = block) when count < 3 do
    _ = Logger.info("Retrying insertion of block #{block.blknum}")
    PendingBlock.update(block, %{retry_count: block.retry_count + 1})
    :ok
  end

  defp handle_insert_error(block) do
    _ = Logger.info("Block insertion failed for block #{block.blknum}")
    PendingBlock.update(block, %{status: PendingBlock.status_failed()})
    :ok
  end
end
