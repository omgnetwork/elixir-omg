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

defmodule OMG.Watcher.BlockGetter.Supervisor do
  @moduledoc """
  This supervisor takes care of BlockGetter and State processes.
  In case one process fails, this supervisor's role is to restore consistent state
  """
  use Supervisor
  use OMG.Utils.LoggerExt
  import Telemetry.Metrics

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    # State and Block Getter are linked, because they must restore their state to the last stored state
    # If Block Getter fails, it starts from the last checkpoint while State might have had executed some transactions
    # such a situation will cause error when trying to execute already executed transaction
    children = [
      {TelemetryMetricsStatsd,
       [
         metrics: [
           last_value("watcher.unique_users.value", event_name: "Elixir.OMG.State.unique_users"),
           last_value("watcher.balance.value", event_name: "Elixir.OMG.State.balance", tags: [:coin]),
           last_value("watche.block_getter.message_queue_len",
             event_name: "OMG.Watcher.BlockGetter.Recorder",
             tags: [:node]
           )
         ],
         formatter: :datadog
       ]},
      {OMG.State, []},
      %{
        id: OMG.Watcher.BlockGetter,
        start: {OMG.Watcher.BlockGetter, :start_link, [[]]},
        restart: :transient
      }
    ]

    opts = [strategy: :one_for_all]

    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    Supervisor.init(children, opts)
  end
end
