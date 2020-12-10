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

defmodule OMG.EthereumEventListener.Core do
  @moduledoc """
  Logic module for the `OMG.EthereumEventListener`

  Responsible for:
    - deciding what ranges of Ethereum events should be fetched from the Ethereum node
    - deciding the right size of event batches to read (too little means many RPC requests, too big can timeout)
    - deciding what to check in into the `OMG.RootChainCoordinator`
    - deciding what to put into the `OMG.DB` in terms of Ethereum height till which the events are already processed

  Leverages a rudimentary in-memory cache for events, to be able to ask for right-sized batches of events
  """
  alias OMG.RootChainCoordinator.SyncGuide

  use Spandex.Decorators

  # synced_height is what's being exchanged with `RootChainCoordinator`.
  # The point in root chain until where it processed
  defstruct synced_height_update_key: nil,
            service_name: nil,
            synced_height: 0,
            ethereum_events_check_interval_ms: nil,
            request_max_size: 1000

  @type event :: %{eth_height: non_neg_integer()}

  @type t() :: %__MODULE__{
          synced_height_update_key: atom(),
          service_name: atom(),
          synced_height: integer(),
          ethereum_events_check_interval_ms: non_neg_integer(),
          request_max_size: pos_integer()
        }

  @doc """
  Initializes the listener logic based on its configuration and the last persisted Ethereum height, till which events
  were processed
  """
  @spec init(atom(), atom(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: {t(), non_neg_integer()}

  def init(
        update_key,
        service_name,
        last_synced_ethereum_height,
        ethereum_events_check_interval_ms,
        request_max_size \\ 1000
      ) do
    initial_state = %__MODULE__{
      synced_height_update_key: update_key,
      synced_height: last_synced_ethereum_height,
      service_name: service_name,
      request_max_size: request_max_size,
      ethereum_events_check_interval_ms: ethereum_events_check_interval_ms
    }

    {initial_state, last_synced_ethereum_height}
  end

  @doc """
  Returns the events range -
  - from (inclusive!),
  - to (inclusive!)
  that needs to be scraped and sets synced_height in the state.

  """
  @decorate span(service: :ethereum_event_listener, type: :backend, name: "calc_events_range_set_height/2")
  @spec calc_events_range_set_height(t(), SyncGuide.t()) ::
          {:dont_fetch_events, t()} | {{non_neg_integer, non_neg_integer}, t()}
  def calc_events_range_set_height(state, sync_guide) do
    case sync_guide.sync_height <= state.synced_height do
      true ->
        {:dont_fetch_events, state}

      _ ->
        # if sync_guide.sync_height has applied margin (reorg protection)
        # the only thing we need to be aware of is that we don't go pass that!
        # but we want to move as fast as possible so we try to fetch as much as we can (request_max_size)
        first_not_visited = state.synced_height + 1
        # if first not visited = 1, and request max size is 10
        # it means we can scrape AT MOST request_max_size events
        max_height = state.request_max_size - 1
        upper_bound = min(sync_guide.sync_height, first_not_visited + max_height)

        {{first_not_visited, upper_bound}, %{state | synced_height: upper_bound}}
    end
  end
end
