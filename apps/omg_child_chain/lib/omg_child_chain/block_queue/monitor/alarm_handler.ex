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

defmodule OMG.ChildChain.BlockQueue.Monitor.AlarmHandler do
  @moduledoc """
  Listens for :block_submit_stalled alarms and reflect the alarm's state back to the monitor.
  """
  require Logger

  # The alarm reporter and monitor happen to be the same module here because we are just
  # reflecting the alarm's state back to the reporter.
  @reporter OMG.ChildChain.BlockQueue.Monitor
  @monitor OMG.ChildChain.BlockQueue.Monitor

  def init(_args) do
    {:ok, %{}}
  end

  def handle_call(_request, state), do: {:ok, :ok, state}

  def handle_event({:set_alarm, {:block_submit_stalled, %{reporter: @reporter}}}, state) do
    _ = Logger.warn(":block_submit_stalled alarm raised.")
    :ok = GenServer.cast(@monitor, {:set_alarm, :block_submit_stalled})
    {:ok, state}
  end

  def handle_event({:clear_alarm, {:block_submit_stalled, %{reporter: @reporter}}}, state) do
    _ = Logger.warn(":block_submit_stalled alarm cleared.")
    :ok = GenServer.cast(@monitor, {:clear_alarm, :block_submit_stalled})
    {:ok, state}
  end

  def handle_event(event, state) do
    _ = Logger.info("#{__MODULE__} got event: #{inspect(event)}. Ignoring.")
    {:ok, state}
  end
end
