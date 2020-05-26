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

defmodule OMG.Watcher.API.StatusCache do
  @moduledoc """
  Watcher status API
  """

  alias OMG.Eth
  alias OMG.Eth.Client
  alias OMG.Eth.Configuration
  alias OMG.Eth.RootChain
  alias OMG.RootChainCoordinator
  alias OMG.State
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.Watcher.BlockGetter
  alias OMG.Watcher.Event
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.SyncSupervisor

  use GenServer

  @opaque status() :: %{
            last_validated_child_block_number: non_neg_integer(),
            last_validated_child_block_timestamp: non_neg_integer(),
            last_mined_child_block_number: non_neg_integer(),
            last_mined_child_block_timestamp: non_neg_integer(),
            last_seen_eth_block_number: non_neg_integer(),
            last_seen_eth_block_timestamp: non_neg_integer(),
            eth_syncing: boolean(),
            byzantine_events: list(Event.t()),
            in_flight_exits: ExitProcessor.Core.in_flight_exits_response_t(),
            contract_addr: binary,
            services_synced_heights: RootChainCoordinator.Core.ethereum_heights_result_t()
          }

  @type t() :: atom()

  @spec get() :: status()
  def get() do
    :ets.lookup_element(SyncSupervisor.status_cache(), key(), 2)
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @spec init(Keyword.t()) :: {:ok, t()}
  def init(opts) do
    event_bus = Keyword.fetch!(opts, :event_bus)
    ets = Keyword.fetch!(opts, :ets)
    :ok = event_bus.subscribe({:root_chain, "ethereum_new_height"}, link: true)
    state = ets
    {:ok, state}
  end

  @doc """
  This gets periodically called (defined by Ethereum height change).
  """
  def handle_info({:internal_event_bus, :ethereum_new_height, eth_block_number}, state) do
    {:ok, status} = get_status(eth_block_number)
    _ = :ets.insert(state, {key(), Jason.encode!(status)})
    {:noreply, state}
  end

  # Returns status of the watcher. Status consists of last validated child block number,
  # last mined child block number and it's timestamp, and a flag indicating if watcher is syncing with Ethereum.

  # This function calls into a number of services (internal and external), collects the results. If any of the underlying
  # services are unavailable, it will crash
  @spec get_status(non_neg_integer()) :: {:ok, status()}
  defp get_status(eth_block_number) do
    {:ok, eth_block_timestamp} = Eth.get_block_timestamp_by_number(eth_block_number)
    eth_syncing = syncing?()

    validated_child_block_number = get_validated_child_block_number()
    contracts = Configuration.contracts()
    contract_addr = contract_map_from_hex(contracts)

    mined_child_block_number = RootChain.get_mined_child_block()

    {_, mined_child_block_timestamp} = RootChain.blocks(mined_child_block_number)

    {_, validated_child_block_timestamp} = RootChain.blocks(validated_child_block_number)

    {:ok, services_synced_heights} = RootChainCoordinator.get_ethereum_heights()

    {_, events_processor} = ExitProcessor.check_validity()
    {:ok, in_flight_exits} = ExitProcessor.get_active_in_flight_exits()

    {:ok, {_, events_block_getter}} = BlockGetter.get_events()

    status = %{
      last_validated_child_block_number: validated_child_block_number,
      last_validated_child_block_timestamp: validated_child_block_timestamp,
      last_mined_child_block_number: mined_child_block_number,
      last_mined_child_block_timestamp: mined_child_block_timestamp,
      last_seen_eth_block_number: eth_block_number,
      last_seen_eth_block_timestamp: eth_block_timestamp,
      eth_syncing: eth_syncing,
      byzantine_events: events_processor ++ events_block_getter,
      in_flight_exits: in_flight_exits,
      contract_addr: contract_addr,
      services_synced_heights: services_synced_heights
    }

    {:ok, status}
  end

  '''
  Checks geth syncing status, errors are treated as not synced.
  Returns:
  * false - geth is synced
  * true  - geth is still syncing.
  '''

  defp syncing?() do
    Client.node_ready() != :ok
  end

  defp get_validated_child_block_number() do
    child_block_interval = Configuration.child_block_interval()
    {state_current_block, _} = State.get_status()
    state_current_block - child_block_interval
  end

  defp contract_map_from_hex(contract_map) do
    Enum.into(contract_map, %{}, fn {name, addr} -> {name, Encoding.from_hex!(addr)} end)
  end

  defp key() do
    :status
  end
end
