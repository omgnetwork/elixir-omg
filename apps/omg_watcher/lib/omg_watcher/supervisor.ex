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

defmodule OMG.Watcher.Supervisor do
  @moduledoc """
  Starts and supervises child processes for the security-critical watcher. It may start its own child processes
  or start other supervisors.
  """
  use Supervisor
  use OMG.Utils.LoggerExt

  alias OMG.Status.Alert.Alarm
  alias OMG.Watcher.DatadogEvent.ContractEventConsumer
  alias OMG.Watcher.Monitor
  alias OMG.Watcher.SyncSupervisor
  alias OMG.Watcher.Tracer

  def start_link() do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [
      {Monitor,
       [
         Alarm,
         %{
           id: SyncSupervisor,
           start: {SyncSupervisor, :start_link, []},
           restart: :permanent,
           type: :supervisor
         }
       ]}
    ]

    is_datadog_disabled = is_disabled?()

    rest_children =
      if is_datadog_disabled do
        children
      else
        create_event_consumer_children() ++ children
      end

    opts = [strategy: :one_for_one]

    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    Supervisor.init(rest_children, opts)
  end

  defp create_event_consumer_children() do
    Enum.map(
      [
        "blocks",
        "DepositCreated",
        "InFlightExitInputPiggybacked",
        "InFlightExitOutputPiggybacked",
        "BlockSubmitted",
        "ExitFinalized",
        "ExitChallenged",
        "InFlightExitChallenged",
        "InFlightExitChallengeResponded",
        "InFlightExitInputBlocked",
        "InFlightExitOutputBlocked",
        "InFlightExitInputWithdrawn",
        "InFlightExitOutputWithdrawn",
        "InFlightExitStarted",
        "ExitStarted"
      ],
      fn event ->
        ContractEventConsumer.prepare_child(
          event: event,
          release: Application.get_env(:omg_watcher, :release),
          current_version: Application.get_env(:omg_watcher, :current_version),
          publisher: OMG.Status.Metric.Datadog
        )
      end
    )
  end

  @spec is_disabled?() :: boolean()
  defp is_disabled?(), do: Application.get_env(:omg_watcher, Tracer)[:disabled?]
end
