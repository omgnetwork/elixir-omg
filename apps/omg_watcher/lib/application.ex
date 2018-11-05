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

defmodule OMG.Watcher.Application do
  @moduledoc false
  use Application
  use OMG.API.LoggerExt

  def start(_type, _args) do
    start_root_supervisor()
  end

  def start_root_supervisor do
    # root supervisor must stop whenever any of its children goes down

    children = [
      %{
        id: OMG.Watcher.Supervisor,
        start: {__MODULE__, :start_watcher_supervisor, []},
        restart: :permanent,
        type: :supervisor
      },
      %{
        id: OMG.Watcher.BlockGetter.Supervisor,
        start: {OMG.Watcher.BlockGetter.Supervisor, :start_link, []},
        restart: :permanent,
        type: :supervisor
      }
    ]

    opts = [
      strategy: :one_for_one,
      # whenever any of supervisor's children goes down, so it does
      max_restarts: 0,
      name: OMG.Watcher.RootSupervisor
    ]

    Supervisor.start_link(children, opts)
  end

  def start_watcher_supervisor do
    # Define workers and child supervisors to be supervised
    block_finality_margin = Application.get_env(:omg_api, :ethereum_event_block_finality_margin)
    margin_slow_validator = Application.get_env(:omg_watcher, :margin_slow_validator)

    children = [
      # Start the Ecto repository
      %{
        id: :omg_watcher_repo,
        start: {OMG.Watcher.DB.Repo, :start_link, []},
        type: :supervisor
      },
      # Start workers
      {OMG.Watcher.Eventer, []},
      {
        OMG.API.RootChainCoordinator,
        MapSet.new([:depositor, :fast_validator, :slow_validator, OMG.Watcher.BlockGetter])
      },
      %{
        id: :depositor,
        start:
          {OMG.API.EthereumEventListener, :start_link,
           [
             %{
               synced_height_update_key: :last_depositor_eth_height,
               service_name: :depositor,
               block_finality_margin: block_finality_margin,
               get_events_callback: &OMG.Eth.RootChain.get_deposits/2,
               process_events_callback: &deposit_events_callback/1,
               get_last_synced_height_callback: &OMG.DB.last_depositor_eth_height/0
             }
           ]}
      },
      %{
        id: :fast_validator,
        start:
          {OMG.API.EthereumEventListener, :start_link,
           [
             %{
               block_finality_margin: 0,
               synced_height_update_key: :last_fast_exit_eth_height,
               service_name: :fast_validator,
               get_events_callback: &OMG.Eth.RootChain.get_exits/2,
               process_events_callback: OMG.Watcher.ExitValidator.Validator.challenge_fastly_invalid_exits(),
               get_last_synced_height_callback: &OMG.DB.last_fast_exit_eth_height/0
             }
           ]}
      },
      %{
        id: :slow_validator,
        start:
          {OMG.API.EthereumEventListener, :start_link,
           [
             %{
               block_finality_margin: margin_slow_validator,
               synced_height_update_key: :last_slow_exit_eth_height,
               service_name: :slow_validator,
               get_events_callback: &OMG.Eth.RootChain.get_exits/2,
               process_events_callback: OMG.Watcher.ExitValidator.Validator.challenge_slowly_invalid_exits(),
               get_last_synced_height_callback: &OMG.DB.last_slow_exit_eth_height/0
             }
           ]}
      },
      # Start the endpoint when the application starts
      %{
        id: OMG.Watcher.Web.Endpoint,
        start: {OMG.Watcher.Web.Endpoint, :start_link, []},
        type: :supervisor
      }
    ]

    _ = Logger.info(fn -> "Started application OMG.Watcher.Application" end)

    opts = [strategy: :one_for_one, name: OMG.Watcher.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    OMG.Watcher.Web.Endpoint.config_change(changed, removed)
    :ok
  end

  defp deposit_events_callback(deposits) do
    :ok = OMG.API.State.deposit(deposits)
    _ = OMG.Watcher.DB.EthEvent.insert_deposits(deposits)
    :ok
  end
end
