# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.API.EthereumEventListener.Core do
  @moduledoc """
  Functional core of event listener
  """
  alias OMG.API.RootChainCoordinator.SyncData

  defstruct synced_height_update_key: nil,
            service_name: nil,
            block_finality_margin: 10,
            synced_height: 0,
            cached_size: 1000,
            # FIXME move const variable to config?
            # variable that are modify
            cached_data: %{
              data: [],
              events_uper_bound: 0
            }

  @type event :: %{eth_height: non_neg_integer()}

  @type t() :: %__MODULE__{
          synced_height_update_key: atom(),
          service_name: atom(),
          block_finality_margin: non_neg_integer(),
          cached_size: pos_integer(),
          cached_data: %{
            data: list(event),
            events_uper_bound: non_neg_integer()
          }
        }

  @spec init(atom(), atom(), non_neg_integer(), non_neg_integer()) :: t()
  def init(update_key, service_name, last_synced_ethereum_height, block_finality_margin) do
    %__MODULE__{
      synced_height_update_key: update_key,
      synced_height: last_synced_ethereum_height + block_finality_margin,
      service_name: service_name,
      block_finality_margin: block_finality_margin,
      cached_data: %{data: [], events_uper_bound: last_synced_ethereum_height}
    }
  end

  @doc """
  Returns range Ethereum height to download
  """
  @spec get_events_height_range(t(), SyncData.t()) ::
          {:dont_get_events, t()} | {:get_events, {non_neg_integer, non_neg_integer}, t()}
  def get_events_height_range(
        state = %__MODULE__{cached_data: %{events_uper_bound: uper}},
        %SyncData{sync_height: sync_height}
      )
      when sync_height < uper do
    {:dont_get_events, state}
  end

  def get_events_height_range(
        %__MODULE__{
          cached_size: cached_size,
          cached_data: %{data: data, events_uper_bound: uper_bound} = cached_data
        } = state,
        %SyncData{sync_height: sync_height, root_chain: root_chain_height}
      ) do
    next_upper_bound = min(root_chain_height, uper_bound + cached_size)

    new_state = %__MODULE__{
      state
      | cached_data: %{cached_data | events_uper_bound: next_upper_bound + 1}
    }

    {:get_events, {uper_bound, next_upper_bound}, new_state}
  end

  @spec add_new_events(list(event), t()) :: t()
  def add_new_events(
        new_events,
        %__MODULE__{
          cached_size: cached_size,
          cached_data: %{data: data} = cached_data
        } = state
      ) do
    %__MODULE__{state | cached_data: %{cached_data | data: data ++ new_events}}
  end

  @spec get_events(non_neg_integer, t()) :: {:ok, list(event), list(), t()}
  def get_events(
        sync_height,
        %__MODULE__{
          synced_height_update_key: update_key,
          block_finality_margin: block_finality_margin,
          cached_data: %{data: data} = cached_data
        } = state
      ) do
    sync = sync_height - block_finality_margin
    {events, new_data} = Enum.split_while(data, fn %{eth_height: height} -> height <= sync end)

    db_update = [{:put, update_key, sync}]
    new_state = %__MODULE__{state | synced_height: sync_height , cached_data: %{cached_data | data: new_data}}

    {:ok, events, db_update, new_state}
  end
end
