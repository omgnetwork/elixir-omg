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

defmodule OMG.Status.Metric.Datadog do
  @moduledoc """
  Datadog connection wrapper
  """

  # we want to override Statix in :test
  # because we don't want to send metrics in unittests
  case Application.get_env(:omg_status, :environment) do
    :test -> use OMG.Status.Metric.Statix
    _ -> use Statix, runtime_config: true
  end

  use GenServer
  require Logger

  def start(), do: GenServer.start(__MODULE__, [], [])

  def init(_opts) do
    _ = Logger.info("Starting #{inspect(__MODULE__)} and connecting to Datadog.")
    Process.flag(:trap_exit, true)
    connect()
    {:ok, current_conn()}
  end

  def handle_info({:EXIT, port, reason}, %Statix.Conn{sock: __MODULE__} = state) do
    Logger.error("Port in #{inspect(__MODULE__)} #{inspect(port)} exited with reason #{reason}")
    {:stop, :normal, state}
  end
end
