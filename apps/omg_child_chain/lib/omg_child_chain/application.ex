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

defmodule OMG.ChildChain.Application do
  @moduledoc """
  The application here is the Child chain server and its API.
  See here (children) for the processes that compose into the Child Chain server.
  """
  use Application

  alias OMG.ChildChain.Transaction
  alias OMG.Status.Alert.Alarm

  require Logger

  def start(_type, _args) do
    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    :ok = Alarm.set(Alarm.boot_in_progress(__MODULE__))
    OMG.ChildChain.Supervisor.start_link()
  end

  def start_phase(:boot_done, :normal, _phase_args) do
    :ok = Alarm.clear(Alarm.boot_in_progress(__MODULE__))
  end

  def start_phase(:attach_telemetry, :normal, _phase_args) do
    config = %{
      # DD reserved tag keys -- cannot use: host, device, service, source
      # TODO(jacob) cleanup
      tags: [
        "application:#{Application.get_env(:omg_child_chain, :application)}",
        "app_env:#{Application.get_env(:omg_child_chain, :app_env)}",
        "contract_semver:#{Application.get_env(:omg_child_chain, :contract_semver)}",
        "current_version:#{Application.get_env(:omg_child_chain, :current_version)}",
        "env:#{Application.get_env(:omg_child_chain, :env)}",
        "network:#{Application.get_env(:omg_child_chain, :network)}",
        "release:#{Application.get_env(:omg_child_chain, :release)}",
        # "service:#{Application.get_env(:omg_child_chain, :service)}",
        "service_name:#{Application.get_env(:omg_child_chain, :service_name)}"
      ]
    }

    handlers = [
      [
        "measure-ethereum-event-listener",
        OMG.EthereumEventListener.Measure.supported_events(),
        &OMG.EthereumEventListener.Measure.handle_event/4,
        nil
      ],
      ["measure-state", OMG.State.Measure.supported_events(), &OMG.State.Measure.handle_event/4, nil],
      Transaction.Metrics.events_handler(config)
    ]

    Enum.each(handlers, fn handler ->
      case apply(:telemetry, :attach_many, handler) do
        :ok -> :ok
        {:error, :already_exists} -> :ok
      end
    end)
  end
end
