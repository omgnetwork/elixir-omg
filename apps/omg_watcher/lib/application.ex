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
  @moduledoc """
  See https://hexdocs.pm/elixir/Application.html
  for more information on OTP Applications
  """
  use Application
  use OMG.API.LoggerExt

  def start(_type, _args) do
    import Supervisor.Spec

    # Define workers and child supervisors to be supervised
    slow_exit_validator_block_margin = Application.get_env(:omg_watcher, :slow_exit_validator_block_margin)

    depositer_config = get_event_listener_config(:depositer)
    exiter_config = get_event_listener_config(:exiter)

    children = [
      # Start the Ecto repository
      supervisor(OMG.Watcher.Repo, []),
      # Start workers
      {OMG.API.State, []},
      {OMG.Watcher.Eventer, []},
      {OMG.API.RootchainCoordinator,
       MapSet.new([:depositer, :exiter, :fast_validator, :slow_validator, :block_getter])},
      worker(
        OMG.API.EthereumEventListener,
        [depositer_config, &OMG.Eth.get_deposits/2, &OMG.API.State.deposit/1],
        id: :depositer
      ),
      worker(
        OMG.API.EthereumEventListener,
        [exiter_config, &OMG.Eth.get_exits/2, &OMG.API.State.exit_utxos/1],
        id: :exiter
      ),
      worker(
        OMG.Watcher.ExitValidator,
        [&OMG.DB.last_fast_exit_block_height/0, fn _ -> :ok end, 0, :last_fast_exit_block_height, :fast_validator],
        id: :fast_validator
      ),
      worker(
        OMG.Watcher.ExitValidator,
        [
          &OMG.DB.last_slow_exit_block_height/0,
          &slow_validator_utxo_exists_callback(&1),
          slow_exit_validator_block_margin,
          :last_slow_exit_block_height,
          :slow_validator
        ],
        id: :slow_validator
      ),
      worker(
        OMG.Watcher.BlockGetter,
        [[]],
        restart: :transient,
        id: :block_getter
      ),

      # Start the endpoint when the application starts
      supervisor(OMG.Watcher.Web.Endpoint, [])
    ]

    _ = Logger.info(fn -> "Started application OMG.Watcher.Application" end)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OMG.Watcher.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    OMG.Watcher.Web.Endpoint.config_change(changed, removed)
    :ok
  end

  defp slow_validator_utxo_exists_callback(utxo_exit) do
    with :ok <- OMG.API.State.exit_if_not_spent(utxo_exit) do
      :ok
    else
      :utxo_does_not_exist ->
        :ok = OMG.Watcher.ChainExiter.exit()
        :child_chain_exit
    end
  end

  defp get_event_listener_config(service_name) do
    %{
      block_finality_margin: Application.get_env(:omg_api, :ethereum_event_block_finality_margin),
      service_name: service_name
    }
  end
end
