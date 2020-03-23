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
  use OMG.Utils.LoggerExt
  alias OMG.ChildChain.DatadogEvent.ContractEventConsumer
  alias OMG.ChildChain.FeeServer
  alias OMG.ChildChain.FreshBlocks
  alias OMG.ChildChain.Monitor
  alias OMG.ChildChain.SyncSupervisor
  alias OMG.ChildChain.Tracer
  alias OMG.Eth.RootChain
  alias OMG.State
  alias OMG.Status.Alert.Alarm

  def start_link() do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    # prevent booting if contracts are not ready
    :ok = RootChain.contract_ready()
    {:ok, contract_deployment_height} = RootChain.get_root_deployment_height()
    fee_claimer_address = OMG.Configuration.fee_claimer_address()

    children = [
      {State, [fee_claimer_address: fee_claimer_address]},
      {FreshBlocks, []},
      {FeeServer, []},
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
    child_chain_topics = ["blocks"]
    child_chain_topics = Enum.map(child_chain_topics, &OMG.Bus.Topic.child_chain_topic/1)

    root_chain_topics = [
      "DepositCreated",
      "InFlightExitStarted",
      "InFlightExitInputPiggybacked",
      "InFlightExitOutputPiggybacked",
      "ExitStarted"
    ]

    root_chain_topics = Enum.map(root_chain_topics, &OMG.Bus.Topic.root_chain_topic/1)
    topics = child_chain_topics ++ root_chain_topics

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
