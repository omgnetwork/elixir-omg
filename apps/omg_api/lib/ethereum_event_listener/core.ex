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

  defstruct synced_height_update_key: nil,
            next_event_height_lower_bound: nil,
            synced_height: nil,
            service_name: nil,
            block_finality_margin: 10,
            sync_mode: nil

  @type event :: any

  @type t() :: %__MODULE__{
          synced_height_update_key: atom(),
          next_event_height_lower_bound: non_neg_integer(),
          synced_height: non_neg_integer(),
          service_name: atom(),
          block_finality_margin: non_neg_integer(),
          sync_mode: atom()
        }

  def init(update_key, service_name, last_synced_ethereum_height, block_finality_margin, sync_mode) do
    %__MODULE__{
      synced_height_update_key: update_key,
      next_event_height_lower_bound: max(last_synced_ethereum_height - block_finality_margin + 1, 0),
      synced_height: last_synced_ethereum_height,
      service_name: service_name,
      block_finality_margin: block_finality_margin,
      sync_mode: sync_mode
    }
  end

  @doc """
  Returns next Ethereum height to get events from.
  """
  @spec get_events_height_range_for_next_sync(t(), pos_integer) ::
          {:get_events, {non_neg_integer(), non_neg_integer()}, t(), list()} | {:dont_get_events, t()}
  def get_events_height_range_for_next_sync(state, next_sync_height)

  def get_events_height_range_for_next_sync(%__MODULE__{synced_height: synced_height} = state, next_sync_height)
      when next_sync_height <= synced_height do
    {:dont_get_events, state}
  end

  def get_events_height_range_for_next_sync(
        %__MODULE__{
          synced_height_update_key: update_key,
          next_event_height_lower_bound: next_event_height_lower_bound,
          block_finality_margin: block_finality_margin
        } = state,
        next_sync_height
      ) do
    next_event_height_upper_bound = max(next_sync_height - block_finality_margin, 0)

    new_state = %__MODULE__{
      state
      | synced_height: next_sync_height,
        next_event_height_lower_bound: next_event_height_upper_bound + 1
    }

    db_updates = [{:put, update_key, next_sync_height}]

    {:get_events, {next_event_height_lower_bound, next_event_height_upper_bound}, new_state, db_updates}
  end
end
