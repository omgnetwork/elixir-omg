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
    t_ref = Process.send_after(self(), :check_queue, interval)
    _ = Logger.info("Started #{inspect(__MODULE__)}")
    {:ok, %{interval: interval, timer: t_ref}}
  end

  def handle_info(:check_queue, state) do
    Storage.check_queue()

    t_ref = Process.send_after(self(), :check_queue, state.interval)
    {:noreply, %{state | timer: t_ref}}
  end

  def terminate({%DBConnection.ConnectionError{}, _}, _state) do
    # TODO: raise an alarm?
    :ok
  end

  def terminate(_, _), do: :ok
end
