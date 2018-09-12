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

  def start(_type, _args) do
    block_finality_margin = Application.get_env(:omg_api, :ethereum_event_block_finality_margin)

    children = [
      {OMG.API.State, []},
      {OMG.API.BlockQueue.Server, []},
      {OMG.API.FreshBlocks, []},
      {OMG.API.FeeChecker, []},
      {OMG.API.RootChainCoordinator, MapSet.new([:depositer, :exiter])},
      worker(
        OMG.API.EthereumEventListener,
        [
          %{
            synced_height_update_key: :last_depositer_eth_height,
            service_name: :depositer,
            block_finality_margin: block_finality_margin,
            get_events_callback: &OMG.Eth.RootChain.get_deposits/2,
            process_events_callback: &OMG.API.State.deposit/1,
            get_last_synced_height_callback: &OMG.Eth.RootChain.get_root_deployment_height/0
          }
        ],
        id: :depositer
      ),
      worker(
        OMG.API.EthereumEventListener,
        [
          %{
            synced_height_update_key: :last_exiter_eth_height,
            service_name: :exiter,
            block_finality_margin: block_finality_margin,
            get_events_callback: &OMG.Eth.RootChain.get_exits/2,
            process_events_callback: &OMG.API.State.exit_utxos/1,
            get_last_synced_height_callback: &OMG.Eth.RootChain.get_root_deployment_height/0
          }
        ],
        id: :exiter
      )
    ]

    _ = Logger.info(fn -> "Started application OMG.API.Application" end)
    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end
end
