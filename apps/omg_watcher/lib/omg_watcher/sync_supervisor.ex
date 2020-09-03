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

defmodule OMG.Watcher.SyncSupervisor do
  @moduledoc """
  Starts and supervises security-critical watcher's child processes and supervisors related to
  rootchain synchronisations.
  """
  use Supervisor
  use OMG.Utils.LoggerExt

  alias OMG.EthereumEventListener
  alias OMG.Watcher
  alias OMG.Watcher.API.StatusCache
  alias OMG.Watcher.API.StatusCache.Storage
  alias OMG.Watcher.ChildManager
  alias OMG.Watcher.Configuration
  alias OMG.Watcher.CoordinatorSetup
  alias OMG.Watcher.EthereumEventAggregator
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.Monitor

  @events_bucket :events_bucket
  @status_cache :status_cache

  def status_cache() do
    @status_cache
  end

  def events_bucket() do
    @events_bucket
  end

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    # Assuming the values max_restarts and max_seconds,
    # then, if more than max_restarts restarts occur within max_seconds seconds,
    # the supervisor terminates all child processes and then itself.
    # The termination reason for the supervisor itself in that case will be shutdown.
    # max_restarts defaults to 3 and max_seconds defaults to 5.

    # We have 16 children, roughly 14 of them have a dependency to the internetz.
    # The internetz is flaky. We account for that and allow the flakyness to pass
    # by increasing the restart strategy. But not too much, because if the internetz is
    # really off, HeightMonitor should catch that in max 8 seconds and raise an alarm.
    max_restarts = 3
    max_seconds = 5
    opts = [strategy: :one_for_one, max_restarts: max_restarts * 10, max_seconds: max_seconds * 2]

    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    :ok = Storage.ensure_ets_init(status_cache())
    :ok = ensure_ets_init(events_bucket())
    Supervisor.init(children(args), opts)
  end

  defp children(args) do
    contract_deployment_height = Keyword.fetch!(args, :contract_deployment_height)
    exit_processor_sla_margin = Configuration.exit_processor_sla_margin()
    exit_processor_sla_margin_forced = Configuration.exit_processor_sla_margin_forced()
    metrics_collection_interval = Configuration.metrics_collection_interval()
    finality_margin = Configuration.exit_finality_margin()
    deposit_finality_margin = OMG.Configuration.deposit_finality_margin()
    ethereum_events_check_interval_ms = OMG.Configuration.ethereum_events_check_interval_ms()
    coordinator_eth_height_check_interval_ms = OMG.Configuration.coordinator_eth_height_check_interval_ms()
    min_exit_period_seconds = OMG.Eth.Configuration.min_exit_period_seconds()
    ethereum_block_time_seconds = OMG.Eth.Configuration.ethereum_block_time_seconds()
    child_block_interval = OMG.Eth.Configuration.child_block_interval()
    contracts = OMG.Eth.Configuration.contracts()

    [
      {OMG.RootChainCoordinator,
       CoordinatorSetup.coordinator_setup(
         metrics_collection_interval,
         coordinator_eth_height_check_interval_ms,
         finality_margin,
         deposit_finality_margin
       )},
      {ExitProcessor,
       [
         exit_processor_sla_margin: exit_processor_sla_margin,
         exit_processor_sla_margin_forced: exit_processor_sla_margin_forced,
         metrics_collection_interval: metrics_collection_interval,
         min_exit_period_seconds: min_exit_period_seconds,
         ethereum_block_time_seconds: ethereum_block_time_seconds,
         child_block_interval: child_block_interval
       ]},
      %{
        id: OMG.Watcher.BlockGetter.Supervisor,
        start:
          {OMG.Watcher.BlockGetter.Supervisor, :start_link, [[contract_deployment_height: contract_deployment_height]]},
        restart: :permanent,
        type: :supervisor
      },
      {EthereumEventAggregator,
       contracts: contracts,
       ets_bucket: events_bucket(),
       events: [
         [name: :deposit_created, enrich: false],
         [name: :exit_started, enrich: true],
         [name: :exit_finalized, enrich: false],
         [name: :exit_challenged, enrich: false],
         [name: :in_flight_exit_started, enrich: true],
         [name: :in_flight_exit_input_piggybacked, enrich: false],
         [name: :in_flight_exit_output_piggybacked, enrich: false],
         [name: :in_flight_exit_challenged, enrich: true],
         [name: :in_flight_exit_challenge_responded, enrich: false],
         [name: :in_flight_exit_input_blocked, enrich: false],
         [name: :in_flight_exit_output_blocked, enrich: false],
         [name: :in_flight_exit_input_withdrawn, enrich: false],
         [name: :in_flight_exit_output_withdrawn, enrich: false]
       ]},
      EthereumEventListener.prepare_child(
        metrics_collection_interval: metrics_collection_interval,
        ethereum_events_check_interval_ms: ethereum_events_check_interval_ms,
        contract_deployment_height: contract_deployment_height,
        service_name: :depositor,
        synced_height_update_key: :last_depositor_eth_height,
        get_events_callback: &EthereumEventAggregator.deposit_created/2,
        process_events_callback: &OMG.State.deposit/1
      ),
      EthereumEventListener.prepare_child(
        metrics_collection_interval: metrics_collection_interval,
        ethereum_events_check_interval_ms: ethereum_events_check_interval_ms,
        contract_deployment_height: contract_deployment_height,
        service_name: :exit_processor,
        synced_height_update_key: :last_exit_processor_eth_height,
        get_events_callback: &EthereumEventAggregator.exit_started/2,
        process_events_callback: &Watcher.ExitProcessor.new_exits/1
      ),
      EthereumEventListener.prepare_child(
        metrics_collection_interval: metrics_collection_interval,
        ethereum_events_check_interval_ms: ethereum_events_check_interval_ms,
        contract_deployment_height: contract_deployment_height,
        service_name: :exit_finalizer,
        synced_height_update_key: :last_exit_finalizer_eth_height,
        get_events_callback: &EthereumEventAggregator.exit_finalized/2,
        process_events_callback: &Watcher.ExitProcessor.finalize_exits/1
      ),
      EthereumEventListener.prepare_child(
        metrics_collection_interval: metrics_collection_interval,
        ethereum_events_check_interval_ms: ethereum_events_check_interval_ms,
        contract_deployment_height: contract_deployment_height,
        service_name: :exit_challenger,
        synced_height_update_key: :last_exit_challenger_eth_height,
        get_events_callback: &EthereumEventAggregator.exit_challenged/2,
        process_events_callback: &Watcher.ExitProcessor.challenge_exits/1
      ),
      EthereumEventListener.prepare_child(
        metrics_collection_interval: metrics_collection_interval,
        ethereum_events_check_interval_ms: ethereum_events_check_interval_ms,
        contract_deployment_height: contract_deployment_height,
        service_name: :in_flight_exit_processor,
        synced_height_update_key: :last_in_flight_exit_processor_eth_height,
        get_events_callback: &EthereumEventAggregator.in_flight_exit_started/2,
        process_events_callback: &Watcher.ExitProcessor.new_in_flight_exits/1
      ),
      EthereumEventListener.prepare_child(
        metrics_collection_interval: metrics_collection_interval,
        ethereum_events_check_interval_ms: ethereum_events_check_interval_ms,
        contract_deployment_height: contract_deployment_height,
        service_name: :piggyback_processor,
        synced_height_update_key: :last_piggyback_processor_eth_height,
        get_events_callback: &EthereumEventAggregator.in_flight_exit_piggybacked/2,
        process_events_callback: &Watcher.ExitProcessor.piggyback_exits/1
      ),
      EthereumEventListener.prepare_child(
        metrics_collection_interval: metrics_collection_interval,
        ethereum_events_check_interval_ms: ethereum_events_check_interval_ms,
        contract_deployment_height: contract_deployment_height,
        service_name: :competitor_processor,
        synced_height_update_key: :last_competitor_processor_eth_height,
        get_events_callback: &EthereumEventAggregator.in_flight_exit_challenged/2,
        process_events_callback: &Watcher.ExitProcessor.new_ife_challenges/1
      ),
      EthereumEventListener.prepare_child(
        metrics_collection_interval: metrics_collection_interval,
        ethereum_events_check_interval_ms: ethereum_events_check_interval_ms,
        contract_deployment_height: contract_deployment_height,
        service_name: :challenges_responds_processor,
        synced_height_update_key: :last_challenges_responds_processor_eth_height,
        get_events_callback: &EthereumEventAggregator.in_flight_exit_challenge_responded/2,
        process_events_callback: &Watcher.ExitProcessor.respond_to_in_flight_exits_challenges/1
      ),
      EthereumEventListener.prepare_child(
        metrics_collection_interval: metrics_collection_interval,
        ethereum_events_check_interval_ms: ethereum_events_check_interval_ms,
        contract_deployment_height: contract_deployment_height,
        service_name: :piggyback_challenges_processor,
        synced_height_update_key: :last_piggyback_challenges_processor_eth_height,
        get_events_callback: &EthereumEventAggregator.in_flight_exit_blocked/2,
        process_events_callback: &Watcher.ExitProcessor.challenge_piggybacks/1
      ),
      EthereumEventListener.prepare_child(
        metrics_collection_interval: metrics_collection_interval,
        ethereum_events_check_interval_ms: ethereum_events_check_interval_ms,
        contract_deployment_height: contract_deployment_height,
        service_name: :ife_exit_finalizer,
        synced_height_update_key: :last_ife_exit_finalizer_eth_height,
        get_events_callback: &EthereumEventAggregator.in_flight_exit_withdrawn/2,
        process_events_callback: &Watcher.ExitProcessor.finalize_in_flight_exits/1
      ),
      {StatusCache, [event_bus: OMG.Bus, ets: status_cache()]},
      {ChildManager, [monitor: Monitor]}
    ]
  end

  defp ensure_ets_init(events_bucket) do
    case :ets.info(events_bucket) do
      :undefined ->
        ^events_bucket = :ets.new(events_bucket, [:bag, :public, :named_table])
        :ok

      _ ->
        :ok
    end
  end
end
