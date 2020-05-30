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
  alias OMG.WatcherInfo.DB.Block
  alias OMG.WatcherInfo.DB.PendingBlock
  require Logger

  ### Client

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  ### Server

  use GenServer

  def init(args) do
    interval = Keyword.fetch!(args, :processing_interval)
    {:ok, processing_timer} = :timer.send_interval(interval, self(), :process_block)

    _ = Logger.info("Started #{inspect(__MODULE__)}")
    {:ok, %{processing_timer: processing_timer}}
  end

  def handle_info(:process_block, state) do
    case PendingBlock.get_next_to_process() do
      nil ->
        {:noreply, state}

      block ->
        process_block(block)
        {:noreply, state}
    end
  end

  defp process_block(block) do
    # TODO: process "processing" block when app start

    Block.insert_pending_block(block)
    # set state as done
  end
end
