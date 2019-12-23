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

defmodule OMG.Watcher.ChildManager do
  @moduledoc """
    Reports it's health to the Monitor after start or restart and shutsdown.
  """
  use GenServer, restart: :transient

  require Logger
  @timer 5_000
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    monitor = Keyword.fetch!(args, :monitor)
    {:ok, _tref} = :timer.send_after(@timer, :health_checkin)
    {:ok, %{timer: @timer, monitor: monitor}}
  end

  def handle_info(:health_checkin, state) do
    :ok = state.monitor.health_checkin()

    {:stop, :normal, state}
  end
end
