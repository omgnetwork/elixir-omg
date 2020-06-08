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

defmodule OMG.ChildChain.Supervisor do
  @moduledoc """
   OMG.ChildChain top level supervisor.
  """
  use Supervisor

  alias OMG.ChildChain.API.BlocksCache
  alias OMG.ChildChain.API.BlocksCache.Storage
  alias OMG.ChildChain.Configuration
  alias OMG.ChildChain.DatadogEvent.ContractEventConsumer
  alias OMG.ChildChain.FeeServer
  alias OMG.ChildChain.Monitor
  alias OMG.ChildChain.SyncSupervisor
  alias OMG.ChildChain.Tracer
  alias OMG.Eth.RootChain
  alias OMG.State
  alias OMG.Status.Alert.Alarm

  require Logger

  @blocks_cache :blocks_cache

  def blocks_cache() do
    @blocks_cache
  end

  def start_link() do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    :ok = Storage.ensure_ets_init(blocks_cache())
    {:ok, contract_deployment_height} = RootChain.get_root_deployment_height()
    metrics_collection_interval = Configuration.metrics_collection_interval()
    fee_server_opts = Configuration.fee_server_opts()
    fee_claimer_address = OMG.Configuration.fee_claimer_address()
    child_block_interval = OMG.Eth.Configuration.child_block_interval()

    children = [
      {State,
       [
         fee_claimer_address: fee_claimer_address,
         child_block_interval: child_block_interval,
         metrics_collection_interval: metrics_collection_interval
       ]},
      {BlocksCache, [ets: blocks_cache()]},
      {FeeServer, fee_server_opts},
      {Monitor,
       [
         Alarm,
         %{
           id: SyncSupervisor,
           start: {SyncSupervisor, :start_link, [[contract_deployment_height: contract_deployment_height]]},
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
    topics =
      Enum.map(
        [
          "blocks",
          "DepositCreated",
          "InFlightExitStarted",
          "InFlightExitInputPiggybacked",
          "InFlightExitOutputPiggybacked",
          "ExitStarted"
        ],
        &{:root_chain, &1}
      )

    Enum.map(
      topics,
      fn topic ->
        ContractEventConsumer.prepare_child(
          topic: topic,
          release: Application.get_env(:omg_child_chain, :release),
          current_version: Application.get_env(:omg_child_chain, :current_version),
          publisher: OMG.Status.Metric.Datadog
        )
      end
    )
  end

  @spec is_disabled?() :: boolean()
  defp is_disabled?(), do: Application.get_env(:omg_child_chain, Tracer)[:disabled?]
end
