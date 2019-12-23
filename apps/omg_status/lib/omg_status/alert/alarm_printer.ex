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

defmodule OMG.Status.AlarmPrinter do
  @moduledoc """
    A loud reminder of raised events
  """
  use GenServer
  require Logger
  @interval 5_000
  # 5 minutes
  @max_interval 300_000
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    alarm_module = Keyword.fetch!(args, :alarm_module)
    _ = :timer.send_after(@interval, :print_alarms)
    {:ok, %{previous_backoff: @interval, alarm_module: alarm_module}}
  end

  def handle_info(:print_alarms, state) do
    :ok = Enum.each(state.alarm_module.all(), fn alarm -> Logger.warn("An alarm was raised #{inspect(alarm)}") end)

    previous_backoff =
      case @max_interval < state.previous_backoff do
        true ->
          @interval

        false ->
          state.previous_backoff
      end

    next_backoff = round(previous_backoff * 2) + Enum.random(-1000..1000)

    _ = :timer.send_after(next_backoff, :print_alarms)
    {:noreply, Map.put(state, :previous_backoff, next_backoff)}
  end
end
