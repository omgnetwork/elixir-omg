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

defmodule OMG.API.Application do
  @moduledoc """
  The application here is the Child chain server and its API.
  See here (children) for the processes that compose into the Child Chain server.
  """

  use Application
  use OMG.API.LoggerExt
  import Supervisor.Spec
  alias OMG.API.State

  def start(_type, _args) do
    depositer_config = get_event_listener_config(:depositer, :last_depositer_block_height)
    exiter_config = get_event_listener_config(:exiter, :last_exiter_block_height)

    children = [
      {OMG.API.State, []},
      {OMG.API.BlockQueue.Server, []},
      {OMG.API.FreshBlocks, []},
      {OMG.API.FeeChecker, []},
      {OMG.API.RootchainCoordinator, MapSet.new([:depositer, :exiter])},
      worker(
        OMG.API.EthereumEventListener,
        [depositer_config, &OMG.Eth.get_deposits/2, &State.deposit/1, &OMG.Eth.get_root_deployment_height/0],
        id: :depositer
      ),
      worker(
        OMG.API.EthereumEventListener,
        [exiter_config, &OMG.Eth.get_exits/2, &State.exit_utxos/1, &OMG.Eth.get_root_deployment_height/0],
        id: :exiter
      )
    ]

    _ = Logger.info(fn -> "Started application OMG.API.Application" end)
    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end

  defp get_event_listener_config(service_name, synced_height_update_key) do
    %{
      block_finality_margin: Application.get_env(:omg_api, :ethereum_event_block_finality_margin),
      synced_height_update_key: synced_height_update_key,
      service_name: service_name
    }
  end
end
