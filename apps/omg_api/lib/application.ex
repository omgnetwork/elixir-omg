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

  def start(_type, _args) do
    eth_deposit_finality_margin = Application.get_env(:omg_api, :eth_deposit_finality_margin)

    children = [
      {OMG.API.State, []},
      {OMG.API.BlockQueue.Server, []},
      {OMG.API.FreshBlocks, []},
      {OMG.API.FeeChecker, []},
      {OMG.API.RootChainCoordinator, [:depositor, :exiter, :in_flight_exit]},
      %{
        id: :depositor,
        start:
          {OMG.API.EthereumEventListener, :start_link,
           [
             %{
               block_finality_margin: eth_deposit_finality_margin,
               synced_height_update_key: :last_depositor_eth_height,
               service_name: :depositor,
               get_events_callback: &OMG.Eth.RootChain.get_deposits/2,
               process_events_callback: &OMG.API.State.deposit/1,
               get_last_synced_height_callback: &OMG.Eth.RootChain.get_root_deployment_height/0
             }
           ]}
      },
      %{
        id: :in_flight_exit,
        start: {
          OMG.API.EthereumEventListener,
          :start_link,
          [
            %{
              # TODO check if synced_height_update_key is appropriate
              synced_height_update_key: :last_exiter_eth_height,
              service_name: :in_flight_exit,
              block_finality_margin: eth_deposit_finality_margin,
              get_events_callback: &OMG.Eth.RootChain.get_in_flight_exit_starts/2,
              process_events_callback: &OMG.API.State.in_flight_exit/1,
              get_last_synced_height_callback: &OMG.Eth.RootChain.get_root_deployment_height/0
            }
          ]
        }
      },
      %{
        id: :exiter,
        start:
          {OMG.API.EthereumEventListener, :start_link,
           [
             %{
               # 0, because we want the child chain to make UTXOs spent immediately after exit starts
               block_finality_margin: 0,
               synced_height_update_key: :last_exiter_eth_height,
               service_name: :exiter,
               get_events_callback: &OMG.Eth.RootChain.get_exits/2,
               process_events_callback: fn exits ->
                 {status, db_updates, _validities} = OMG.API.State.exit_utxos(exits)
                 {status, db_updates}
               end,
               get_last_synced_height_callback: &OMG.Eth.RootChain.get_root_deployment_height/0
             }
           ]}
      }
    ]

    _ = Logger.info(fn -> "Started application OMG.API.Application" end)
    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end
end
