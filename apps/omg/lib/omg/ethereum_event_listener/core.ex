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
  Periodically fetches events made on dynamically changing block range
  on parent chain and feeds them to a callback.

  It is **not** responsible for figuring out which ranges of eth-blocks to scan and when, see
  `OMG.RootChainCoordinator.Core` for that.

  It **is** responsible for processing all events and processing them only once. The only "help" from the coordinator
  it gets is in that it receives the `SyncGuide` that takes some finality (reorg) margin into account.

  NOTE: this could and should at some point be implemented as a `@behavior` instead, to avoid using callbacks
  """
  alias OMG.RootChainCoordinator.SyncGuide

  use Spandex.Decorators

  defstruct synced_height_update_key: nil,
            service_name: nil,
            # what's being exchanged with `RootChainCoordinator` - the point in root chain until where it processed
            synced_height: 0,
            cached: %{
              data: [],
              request_max_size: 1000,
              # until which height the events have been pulled and cached
              events_upper_bound: 0
            }

  @type event :: %{eth_height: non_neg_integer()}

  @type t() :: %__MODULE__{
          synced_height_update_key: atom(),
          service_name: atom(),
          cached: %{
            data: list(event),
            request_max_size: pos_integer(),
            events_upper_bound: non_neg_integer()
          }
        }

  @spec init(atom(), atom(), non_neg_integer(), non_neg_integer()) :: {t(), non_neg_integer()} | {:error, :invalid_init}
  def init(update_key, service_name, last_synced_ethereum_height, request_max_size \\ 1000)

  def init(update_key, service_name, last_synced_ethereum_height, request_max_size) when request_max_size > 0 do
    initial_state = %__MODULE__{
      synced_height_update_key: update_key,
      synced_height: last_synced_ethereum_height,
      service_name: service_name,
      cached: %{
        request_max_size: request_max_size,
        data: [],
        events_upper_bound: last_synced_ethereum_height
      }
    }

    {initial_state, get_height_to_check_in(initial_state)}
  end

  def init(_, _, _, _), do: {:error, :invalid_init}

  @doc """
  Provides a uniform way to get the height to check in.

  Every call to RootChainCoordinator.check_in should use value taken from this, after all mutations to the state
  """
  @spec get_height_to_check_in(t()) :: non_neg_integer()
  def get_height_to_check_in(%__MODULE__{synced_height: synced_height}), do: synced_height

  @doc """
  Returns range Ethereum height to download
  """
  @decorate span(service: :ethereum_event_listener, type: :backend, name: "get_events_range_for_download/2")
  @spec get_events_range_for_download(t(), SyncGuide.t()) ::
          {:dont_fetch_events, t()} | {:get_events, {non_neg_integer, non_neg_integer}, t()}
  def get_events_range_for_download(%__MODULE__{cached: %{events_upper_bound: upper}} = state, %SyncGuide{
        sync_height: sync_height
      })
      when sync_height <= upper,
      do: {:dont_fetch_events, state}

  @decorate span(service: :ethereum_event_listener, type: :backend, name: "get_events_range_for_download/2")
  def get_events_range_for_download(
        %__MODULE__{
          cached: %{request_max_size: request_max_size, events_upper_bound: old_upper_bound} = cached_data
        } = state,
        %SyncGuide{root_chain_height: root_chain_height, sync_height: sync_height}
      ) do
    # grab as much as allowed, but not higher than current root_chain_height and at least as much as needed to sync
    # NOTE: both root_chain_height and sync_height are assumed to have any required finality margins applied by caller
    next_upper_bound =
      min(root_chain_height, old_upper_bound + request_max_size)
      |> max(sync_height)

    new_state = %__MODULE__{
      state
      | cached: %{cached_data | events_upper_bound: next_upper_bound}
    }

    {:get_events, {old_upper_bound + 1, next_upper_bound}, new_state}
  end

  @doc """
  Stores the freshly fetched ethereum events into a memory-cache
  """
  @decorate span(service: :ethereum_event_listener, type: :backend, name: "add_new_events/2")
  @spec add_new_events(t(), list(event)) :: t()
  def add_new_events(
        %__MODULE__{cached: %{data: data} = cached_data} = state,
        new_events
      ) do
    %__MODULE__{state | cached: %{cached_data | data: data ++ new_events}}
  end

  @doc """
  Pop some ethereum events stored in the memory-cache, up to a certain height
  """
  @decorate span(service: :ethereum_event_listener, type: :backend, name: "get_events/2")
  @spec get_events(t(), non_neg_integer) :: {:ok, list(event), list(), non_neg_integer, t()}
  def get_events(
        %__MODULE__{synced_height_update_key: update_key, cached: %{data: data}} = state,
        new_sync_height
      ) do
    {events, new_data} = Enum.split_while(data, fn %{eth_height: height} -> height <= new_sync_height end)

    new_state =
      state
      |> Map.update!(:synced_height, &max(&1, new_sync_height))
      |> Map.update!(:cached, &%{&1 | data: new_data})
      |> struct!()

    height_to_check_in = get_height_to_check_in(new_state)
    db_update = [{:put, update_key, height_to_check_in}]
    {:ok, events, db_update, height_to_check_in, new_state}
  end
end
