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

defmodule OMG.ChildChain.SyncSupervisor do
  @moduledoc """
  Supervises the remainder (i.e. all except the `Watcher.BlockGetter` + `OMG.State` pair, supervised elsewhere)
  of the Watcher app
  """
  use Supervisor
  use OMG.Utils.LoggerExt

  alias OMG.ChildChain.BlockQueue
  alias OMG.ChildChain.BlockQueue.Balance
  alias OMG.ChildChain.BlockQueue.GasAnalyzer
  alias OMG.ChildChain.ChildManager
  alias OMG.ChildChain.Configuration
  alias OMG.ChildChain.CoordinatorSetup
  alias OMG.ChildChain.EthereumEventAggregator
  alias OMG.ChildChain.Monitor
  alias OMG.EthereumEventListener
  alias OMG.RootChainCoordinator
  alias OMG.State

  @events_bucket :events_bucket
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    # Assuming the values max_restarts and max_seconds,
    # then, if more than max_restarts restarts occur within max_seconds seconds,
    # the supervisor terminates all child processes and then itself.
    # The termination reason for the supervisor itself in that case will be shutdown.
    # max_restarts defaults to 3 and max_seconds defaults to 5.

    # We have 9 children, roughly 7 of them have a dependency to the internetz.
    # The internetz is flaky. We account for that and allow the flakyness to pass
    # by increasing the restart strategy. But not too much, because if the internetz is
    # really off, HeightMonitor should catch that in max 8 seconds and raise an alarm.
    max_restarts = 3
    max_seconds = 5
    opts = [strategy: :one_for_one, max_restarts: max_restarts * 5, max_seconds: max_seconds]

    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    :ok = ensure_ets_init()
    Supervisor.init(children(args), opts)
  end

  defp children(args) do
    contract_deployment_height = Keyword.fetch!(args, :contract_deployment_height)
    metrics_collection_interval = Configuration.metrics_collection_interval()
    block_queue_eth_height_check_interval_ms = Configuration.block_queue_eth_height_check_interval_ms()
    submission_finality_margin = Configuration.submission_finality_margin()
    block_submit_every_nth = Configuration.block_submit_every_nth()
    block_submit_max_gas_price = Configuration.block_submit_max_gas_price()
    ethereum_events_check_interval_ms = OMG.Configuration.ethereum_events_check_interval_ms()
    coordinator_eth_height_check_interval_ms = OMG.Configuration.coordinator_eth_height_check_interval_ms()
    deposit_finality_margin = OMG.Configuration.deposit_finality_margin()
    child_block_interval = OMG.Eth.Configuration.child_block_interval()
    contracts = OMG.Eth.Configuration.contracts()
    authority_address = OMG.Eth.Configuration.authority_address()

    [
      {GasAnalyzer, []},
      {Balance, [authority_address: authority_address]},
      {BlockQueue,
       [
         contract_deployment_height: contract_deployment_height,
         metrics_collection_interval: metrics_collection_interval,
         block_queue_eth_height_check_interval_ms: block_queue_eth_height_check_interval_ms,
         submission_finality_margin: submission_finality_margin,
         block_submit_every_nth: block_submit_every_nth,
         block_submit_max_gas_price: block_submit_max_gas_price,
         child_block_interval: child_block_interval
       ]},
      {RootChainCoordinator,
       CoordinatorSetup.coordinator_setup(
         metrics_collection_interval,
         coordinator_eth_height_check_interval_ms,
         deposit_finality_margin
       )},
      {EthereumEventAggregator,
       contracts: contracts,
       ets_bucket: @events_bucket,
       events: [
         [name: :deposit_created, enrich: false],
         [name: :in_flight_exit_started, enrich: true],
         [name: :in_flight_exit_input_piggybacked, enrich: false],
         [name: :in_flight_exit_output_piggybacked, enrich: false],
         [name: :exit_started, enrich: true]
       ]},
      EthereumEventListener.prepare_child(
        metrics_collection_interval: metrics_collection_interval,
        ethereum_events_check_interval_ms: ethereum_events_check_interval_ms,
        contract_deployment_height: contract_deployment_height,
        service_name: :depositor,
        synced_height_update_key: :last_depositor_eth_height,
        get_events_callback: &EthereumEventAggregator.deposit_created/2,
        process_events_callback: &State.deposit/1
      ),
      EthereumEventListener.prepare_child(
        metrics_collection_interval: metrics_collection_interval,
        ethereum_events_check_interval_ms: ethereum_events_check_interval_ms,
        contract_deployment_height: contract_deployment_height,
        service_name: :in_flight_exit,
        synced_height_update_key: :last_in_flight_exit_eth_height,
        get_events_callback: &EthereumEventAggregator.in_flight_exit_started/2,
        process_events_callback: &exit_and_ignore_validities/1
      ),
      EthereumEventListener.prepare_child(
        metrics_collection_interval: metrics_collection_interval,
        ethereum_events_check_interval_ms: ethereum_events_check_interval_ms,
        contract_deployment_height: contract_deployment_height,
        service_name: :piggyback,
        synced_height_update_key: :last_piggyback_exit_eth_height,
        get_events_callback: &EthereumEventAggregator.in_flight_exit_piggybacked/2,
        process_events_callback: &exit_and_ignore_validities/1
      ),
      EthereumEventListener.prepare_child(
        metrics_collection_interval: metrics_collection_interval,
        ethereum_events_check_interval_ms: ethereum_events_check_interval_ms,
        contract_deployment_height: contract_deployment_height,
        service_name: :exiter,
        synced_height_update_key: :last_exiter_eth_height,
        get_events_callback: &EthereumEventAggregator.exit_started/2,
        process_events_callback: &exit_and_ignore_validities/1
      ),
      {ChildManager, [monitor: Monitor]}
    ]
  end

  defp exit_and_ignore_validities([]) do
    {:ok, []}
  end

  defp exit_and_ignore_validities(exits) do
    {status, db_updates, _validities} = State.exit_utxos(exits)
    Logger.warn("================ DEBUG =======================")
    Logger.warn("exit_utxos exits: #{inspect(exits)}")
    Logger.warn("exit_utxos db_updates: #{inspect(db_updates)}")
    Logger.warn("================ DEBUG =======================")
    {status, db_updates}
  end

  defp ensure_ets_init() do
    _ = if :undefined == :ets.info(@events_bucket), do: :ets.new(@events_bucket, [:bag, :public, :named_table])
    :ok
  end
end
