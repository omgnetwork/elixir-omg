# Copyright 2018 OmiseGO Pte Ltd
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
  Supervises the remainder (i.e. all except the `OMG.Watcher.BlockGetter` + `OMG.API.State` pair, supervised elsewhere)
  of the Watcher app
  """
  use Supervisor
  use OMG.API.LoggerExt

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    # Define workers and child supervisors to be supervised
    deposit_finality_margin = Application.fetch_env!(:omg_api, :deposit_finality_margin)
    finality_margin = Application.fetch_env!(:omg_watcher, :exit_finality_margin)

    # FIXME: this could be split out and tested against RootChainCoordinator?
    coordinator_setup = %{
      depositor: [finality_margin: deposit_finality_margin],
      "Elixir.OMG.Watcher.BlockGetter": [waits_for: [depositor: :no_margin], finality_margin: 0],
      exit_processor: [waits_for: :depositor, finality_margin: finality_margin],
      exit_finalizer: [
        waits_for: [:depositor, :"Elixir.OMG.Watcher.BlockGetter", :exit_processor],
        finality_margin: finality_margin
      ],
      exit_challenger: [waits_for: :exit_processor, finality_margin: finality_margin],
      in_flight_exit_processor: [waits_for: :depositor, finality_margin: finality_margin],
      piggyback_processor: [waits_for: :in_flight_exit_processor, finality_margin: finality_margin],
      competitor_processor: [waits_for: :in_flight_exit_processor, finality_margin: finality_margin],
      challenges_responds_processor: [waits_for: :competitor_processor, finality_margin: finality_margin],
      piggyback_challenges_processor: [waits_for: :piggyback_processor, finality_margin: finality_margin],
      ife_exit_finalizer: [
        waits_for: [:depositor, :"Elixir.OMG.Watcher.BlockGetter", :in_flight_exit_processor, :piggyback_processor],
        finality_margin: finality_margin
      ]
    }

    children = [
      # Start the Ecto repository
      %{
        id: OMG.Watcher.DB.Repo,
        start: {OMG.Watcher.DB.Repo, :start_link, []},
        type: :supervisor
      },
      # Start workers
      {OMG.Watcher.Eventer, []},
      {OMG.API.RootChainCoordinator, coordinator_setup},
      OMG.API.EthereumEventListener.prepare_child(
        service_name: :depositor,
        synced_height_update_key: :last_depositor_eth_height,
        get_events_callback: &OMG.Eth.RootChain.get_deposits/2,
        process_events_callback: &deposit_events_callback/1
      ),
      {OMG.Watcher.ExitProcessor, []},
      OMG.API.EthereumEventListener.prepare_child(
        service_name: :exit_processor,
        synced_height_update_key: :last_exit_processor_eth_height,
        get_events_callback: &OMG.Eth.RootChain.get_standard_exits/2,
        process_events_callback: &OMG.Watcher.ExitProcessor.new_exits/1
      ),
      OMG.API.EthereumEventListener.prepare_child(
        service_name: :exit_finalizer,
        synced_height_update_key: :last_exit_finalizer_eth_height,
        get_events_callback: &OMG.Eth.RootChain.get_finalizations/2,
        process_events_callback: &OMG.Watcher.ExitProcessor.finalize_exits/1
      ),
      OMG.API.EthereumEventListener.prepare_child(
        service_name: :exit_challenger,
        synced_height_update_key: :last_exit_challenger_eth_height,
        get_events_callback: &OMG.Eth.RootChain.get_challenges/2,
        process_events_callback: &OMG.Watcher.ExitProcessor.challenge_exits/1
      ),
      OMG.API.EthereumEventListener.prepare_child(
        service_name: :in_flight_exit_processor,
        synced_height_update_key: :last_in_flight_exit_processor_eth_height,
        get_events_callback: &OMG.Eth.RootChain.get_in_flight_exit_starts/2,
        process_events_callback: &OMG.Watcher.ExitProcessor.new_in_flight_exits/1
      ),
      OMG.API.EthereumEventListener.prepare_child(
        service_name: :piggyback_processor,
        synced_height_update_key: :last_piggyback_processor_eth_height,
        get_events_callback: &OMG.Eth.RootChain.get_piggybacks/2,
        process_events_callback: &OMG.Watcher.ExitProcessor.piggyback_exits/1
      ),
      OMG.API.EthereumEventListener.prepare_child(
        service_name: :competitor_processor,
        synced_height_update_key: :last_competitor_processor_eth_height,
        get_events_callback: &OMG.Eth.RootChain.get_in_flight_exit_challenges/2,
        process_events_callback: &OMG.Watcher.ExitProcessor.new_ife_challenges/1
      ),
      OMG.API.EthereumEventListener.prepare_child(
        service_name: :challenges_responds_processor,
        synced_height_update_key: :last_challenges_responds_processor_eth_height,
        get_events_callback: &OMG.Eth.RootChain.get_responds_to_in_flight_exit_challenges/2,
        process_events_callback: &OMG.Watcher.ExitProcessor.respond_to_in_flight_exits_challenges/1
      ),
      OMG.API.EthereumEventListener.prepare_child(
        service_name: :piggyback_challenges_processor,
        synced_height_update_key: :last_piggyback_challenges_processor_eth_height,
        get_events_callback: &OMG.Eth.RootChain.get_piggybacks_challenges/2,
        process_events_callback: &OMG.Watcher.ExitProcessor.challenge_piggybacks/1
      ),
      OMG.API.EthereumEventListener.prepare_child(
        service_name: :ife_exit_finalizer,
        synced_height_update_key: :last_ife_exit_finalizer_eth_height,
        get_events_callback: &OMG.Eth.RootChain.get_in_flight_exit_finalizations/2,
        process_events_callback: &OMG.Watcher.ExitProcessor.finalize_in_flight_exits/1
      ),
      # Start the endpoint when the application starts
      %{
        id: OMG.Watcher.Web.Endpoint,
        start: {OMG.Watcher.Web.Endpoint, :start_link, []},
        type: :supervisor
      }
    ]

    opts = [strategy: :one_for_one]

    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    Supervisor.init(children, opts)
  end

  defp deposit_events_callback(deposits) do
    {:ok, _} = result = OMG.API.State.deposit(deposits)
    _ = OMG.Watcher.DB.EthEvent.insert_deposits(deposits)
    result
  end
end
