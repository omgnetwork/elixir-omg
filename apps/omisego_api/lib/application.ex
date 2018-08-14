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

defmodule OmiseGO.API.Application do
  @moduledoc """
  The application here is the Child chain server and its API.
  See here (children) for the processes that compose into the Child Chain server.
  """

  use Application
  use OmiseGO.API.LoggerExt
  import Supervisor.Spec
  alias OmiseGO.API.State

  def start(_type, _args) do
    event_listener_config = get_event_listener_config()

    children = [
      {OmiseGO.API.State, []},
      {OmiseGO.API.BlockQueue.Server, []},
      {OmiseGO.API.FreshBlocks, []},
      {OmiseGO.API.FeeChecker, []},
      worker(
        OmiseGO.API.EthereumEventListener,
        [event_listener_config, &OmiseGO.Eth.get_deposits/2, &State.deposit/1],
        id: :depositor
      ),
      worker(
        OmiseGO.API.EthereumEventListener,
        [event_listener_config, &OmiseGO.Eth.get_exits/2, &State.exit_utxos/1],
        id: :exiter
      )
    ]

    _ = Logger.info(fn -> "Started application OmiseGO.API.Application" end)
    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end

  defp get_event_listener_config do
    %{
      block_finality_margin: Application.get_env(:omisego_api, :ethereum_event_block_finality_margin),
      max_blocks_in_fetch: Application.get_env(:omisego_api, :ethereum_event_max_block_range_in_deposits_query),
      get_events_interval: Application.get_env(:omisego_api, :ethereum_event_get_deposits_interval_ms)
    }
  end
end
