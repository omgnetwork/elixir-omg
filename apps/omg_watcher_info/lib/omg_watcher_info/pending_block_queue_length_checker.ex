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

defmodule OMG.WatcherInfo.PendingBlockQueueLengthChecker do
  @moduledoc """
  Periodically checks the size of the pending block queue and reports it to telemetry.
  """

  require Logger

  use GenServer

  alias OMG.WatcherInfo.PendingBlockQueueLengthChecker.Storage

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: Keyword.get(args, :name, __MODULE__))
  end

  def init(args) do
    interval = Keyword.fetch!(args, :check_interval)
    _ = Logger.info("Started #{inspect(__MODULE__)}")
    {:ok, %{interval: interval}, interval}
  end

  def handle_info(:timeout, state) do
    length = Storage.get_queue_length()
    _ = :telemetry.execute([:pending_block_queue_length, __MODULE__], %{length: length}, %{})
    {:noreply, state, state.interval}
  end
end
