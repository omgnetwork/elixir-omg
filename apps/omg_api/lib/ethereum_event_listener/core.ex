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

defmodule OMG.API.EthereumEventListener.Core do
  @moduledoc """
  Functional core of event listener
  """
  alias OMG.API.RootChainCoordinator.SyncData

  defstruct synced_height_update_key: nil,
            service_name: nil,
            block_finality_margin: 10,
            synced_height: 0,
            cached: %{
              data: [],
              request_max_size: 1000,
              events_uper_bound: 0
            }

  @type event :: %{eth_height: non_neg_integer()}

  @type t() :: %__MODULE__{
          synced_height_update_key: atom(),
          service_name: atom(),
          block_finality_margin: non_neg_integer(),
          cached: %{
            data: list(event),
            request_max_size: pos_integer(),
            events_uper_bound: non_neg_integer()
          }
        }

  @spec init(atom(), atom(), non_neg_integer(), non_neg_integer()) :: t()
  def init(update_key, service_name, last_synced_ethereum_height, block_finality_margin, request_max_size \\ 1000) do
    %__MODULE__{
      synced_height_update_key: update_key,
      synced_height: last_synced_ethereum_height + block_finality_margin,
      service_name: service_name,
      block_finality_margin: block_finality_margin,
      cached: %{
        request_max_size: request_max_size,
        data: [],
        events_uper_bound: last_synced_ethereum_height + 1
      }
    }
  end

  @doc """
  Returns range Ethereum height to download
  """
  @spec get_events_range_for_download(t(), SyncData.t()) ::
          {:dont_fetch_events, t()} | {:get_events, {non_neg_integer, non_neg_integer}, t()}
  def get_events_range_for_download(
        %__MODULE__{cached: %{events_uper_bound: uper}} = state,
        %SyncData{sync_height: sync_height}
      )
      when sync_height < uper,
      do: {:dont_fetch_events, state}

  def get_events_range_for_download(
        %__MODULE__{
          block_finality_margin: block_finality_margin,
          cached: %{request_max_size: request_max_size, events_uper_bound: old_uper_bound} = cached_data
        } = state,
        %SyncData{sync_height: sync_height, root_chain_height: root_chain_height}
      ) do
    height_need_to_be_download = sync_height - block_finality_margin

    height_limited_by_margin_and_request_size =
      min(root_chain_height - block_finality_margin, old_uper_bound + request_max_size)

    upper_bound = max(height_need_to_be_download, height_limited_by_margin_and_request_size)

    new_state = %__MODULE__{
      state
      | cached: %{cached_data | events_uper_bound: upper_bound + 1}
    }

    {:get_events, {old_uper_bound, upper_bound}, new_state}
  end

  @spec add_new_events(t(), list(event)) :: t()
  def add_new_events(
        %__MODULE__{cached: %{data: data} = cached_data} = state,
        new_events
      ) do
    %__MODULE__{state | cached: %{cached_data | data: data ++ new_events}}
  end

  @spec get_events(t(), non_neg_integer) :: {:ok, list(event), list(), t()}
  def get_events(
        %__MODULE__{
          synced_height_update_key: update_key,
          block_finality_margin: block_finality_margin,
          cached: %{data: data} = cached_data
        } = state,
        sync_height
      ) do
    sync = sync_height - block_finality_margin
    {events, new_data} = Enum.split_while(data, fn %{eth_height: height} -> height <= sync end)

    db_update = [{:put, update_key, sync}]
    new_state = %__MODULE__{state | synced_height: sync_height, cached: %{cached_data | data: new_data}}

    {:ok, events, db_update, new_state}
  end
end
