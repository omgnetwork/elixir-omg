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

defmodule OMG.Watcher.SyncSupervisor do
  @moduledoc """
  Starts and supervises security-critical watcher's child processes and supervisors related to
  rootchain synchronisations.
  """
  use Supervisor
  use OMG.Utils.LoggerExt

  alias OMG.Eth
  alias OMG.EthereumEventListener
  alias OMG.Watcher
  alias OMG.Watcher.CoordinatorSetup

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    opts = [strategy: :one_for_one]

    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    Supervisor.init(children(), opts)
  end

  defp children() do
    [
      %{
        id: OMG.Watcher.BlockGetter.Supervisor,
        start: {OMG.Watcher.BlockGetter.Supervisor, :start_link, []},
        restart: :permanent,
        type: :supervisor
      },
      {OMG.RootChainCoordinator, CoordinatorSetup.coordinator_setup()},
      EthereumEventListener.prepare_child(
        service_name: :depositor,
        synced_height_update_key: :last_depositor_eth_height,
        get_events_callback: &Eth.RootChain.get_deposits/2,
        process_events_callback: &OMG.State.deposit/1
      ),
      {Watcher.ExitProcessor, []},
      EthereumEventListener.prepare_child(
        service_name: :exit_processor,
        synced_height_update_key: :last_exit_processor_eth_height,
        get_events_callback: &Eth.RootChain.get_standard_exits/2,
        process_events_callback: &Watcher.ExitProcessor.new_exits/1
      ),
      EthereumEventListener.prepare_child(
        service_name: :exit_finalizer,
        synced_height_update_key: :last_exit_finalizer_eth_height,
        get_events_callback: &Eth.RootChain.get_finalizations/2,
        process_events_callback: &Watcher.ExitProcessor.finalize_exits/1
      ),
      EthereumEventListener.prepare_child(
        service_name: :exit_challenger,
        synced_height_update_key: :last_exit_challenger_eth_height,
        get_events_callback: &Eth.RootChain.get_challenges/2,
        process_events_callback: &Watcher.ExitProcessor.challenge_exits/1
      ),
      EthereumEventListener.prepare_child(
        service_name: :in_flight_exit_processor,
        synced_height_update_key: :last_in_flight_exit_processor_eth_height,
        get_events_callback: &Eth.RootChain.get_in_flight_exit_starts/2,
        process_events_callback: &Watcher.ExitProcessor.new_in_flight_exits/1
      ),
      EthereumEventListener.prepare_child(
        service_name: :piggyback_processor,
        synced_height_update_key: :last_piggyback_processor_eth_height,
        get_events_callback: &Eth.RootChain.get_piggybacks/2,
        process_events_callback: &Watcher.ExitProcessor.piggyback_exits/1
      ),
      EthereumEventListener.prepare_child(
        service_name: :competitor_processor,
        synced_height_update_key: :last_competitor_processor_eth_height,
        get_events_callback: &Eth.RootChain.get_in_flight_exit_challenges/2,
        process_events_callback: &Watcher.ExitProcessor.new_ife_challenges/1
      ),
      EthereumEventListener.prepare_child(
        service_name: :challenges_responds_processor,
        synced_height_update_key: :last_challenges_responds_processor_eth_height,
        get_events_callback: &Eth.RootChain.get_responds_to_in_flight_exit_challenges/2,
        process_events_callback: &Watcher.ExitProcessor.respond_to_in_flight_exits_challenges/1
      ),
      EthereumEventListener.prepare_child(
        service_name: :piggyback_challenges_processor,
        synced_height_update_key: :last_piggyback_challenges_processor_eth_height,
        get_events_callback: &Eth.RootChain.get_piggybacks_challenges/2,
        process_events_callback: &Watcher.ExitProcessor.challenge_piggybacks/1
      ),
      EthereumEventListener.prepare_child(
        service_name: :ife_exit_finalizer,
        synced_height_update_key: :last_ife_exit_finalizer_eth_height,
        get_events_callback: &Eth.RootChain.get_in_flight_exit_finalizations/2,
        process_events_callback: &Watcher.ExitProcessor.finalize_in_flight_exits/1
      )
    ]
  end
end
