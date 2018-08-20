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

defmodule OMGWatcher.Application do
  @moduledoc """
  See https://hexdocs.pm/elixir/Application.html
  for more information on OTP Applications
  """
  use Application
  use OMG.API.LoggerExt

  def start(_type, _args) do
    import Supervisor.Spec

    # Define workers and child supervisors to be supervised
    slow_exit_validator_block_margin = Application.get_env(:omg_api, :slow_exit_validator_block_margin)

    event_listener_config = %{
      block_finality_margin: Application.get_env(:omg_api, :ethereum_event_block_finality_margin),
      max_blocks_in_fetch: Application.get_env(:omg_api, :ethereum_event_max_block_range_in_deposits_query),
      get_events_interval: Application.get_env(:omg_api, :ethereum_event_get_deposits_interval_ms)
    }

    children = [
      # Start the Ecto repository
      supervisor(OMGWatcher.Repo, []),
      # Start workers
      {OMG.API.State, []},
      {OMGWatcher.Eventer, []},
      worker(
        OMG.API.EthereumEventListener,
        [event_listener_config, &OMG.Eth.get_deposits/2, &OMG.API.State.deposit/1],
        id: :depositor
      ),
      worker(
        OMG.API.EthereumEventListener,
        [event_listener_config, &OMG.Eth.get_exits/2, &OMG.API.State.exit_utxos/1],
        id: :exiter
      ),
      worker(
        OMGWatcher.ExitValidator,
        [&OMG.DB.last_fast_exit_block_height/0, fn _ -> :ok end, 0, :last_fast_exit_block_height],
        id: :fast_validator
      ),
      worker(
        OMGWatcher.ExitValidator,
        [
          &OMG.DB.last_slow_exit_block_height/0,
          &slow_validator_utxo_exists_callback(&1),
          slow_exit_validator_block_margin,
          :last_slow_exit_block_height
        ],
        id: :slow_validator
      ),
      worker(
        OMGWatcher.BlockGetter,
        [[]],
        restart: :transient,
        id: :block_getter
      ),

      # Start the endpoint when the application starts
      supervisor(OMGWatcherWeb.Endpoint, [])
    ]

    _ = Logger.info(fn -> "Started application OMGWatcher.Application" end)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OMGWatcher.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    OMGWatcherWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp slow_validator_utxo_exists_callback(utxo_exit) do
    with :ok <- OMG.API.State.exit_if_not_spent(utxo_exit) do
      :ok
    else
      :utxo_does_not_exist ->
        :ok = OMGWatcher.ChainExiter.exit()
        :child_chain_exit
    end
  end
end
