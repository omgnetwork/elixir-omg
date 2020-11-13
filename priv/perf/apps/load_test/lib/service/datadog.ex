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

defmodule LoadTest.Service.Datadog do
  @moduledoc """
  Datadog connection wrapper
  """

  # we want to override Statix
  # because we don't want to send metrics in unittests
  case Application.get_env(:load_test, :record_metrics) do
    true -> use Statix, runtime_config: true
    _ -> use LoadTest.Service.Datadog.Statix
  end

  use GenServer
  require Logger

  def start_link(_params), do: GenServer.start_link(__MODULE__, [], [])

  def init(_opts) do
    _ = Process.flag(:trap_exit, true)
    _ = Logger.info("Starting #{inspect(__MODULE__)} and connecting to Datadog.")

    :ok = __MODULE__.connect()

    _ = Logger.info("Datadog Connection for Statix was  opened")

    {:ok, []}
  end

  def handle_info({:EXIT, port, reason}, %Statix.Conn{sock: __MODULE__} = state) do
    _ = Logger.error("Port in #{inspect(__MODULE__)} #{inspect(port)} exited with reason #{reason}")
    {:stop, :normal, state}
  end
end
