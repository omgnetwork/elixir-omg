# Copyright 2017 OmiseGO Pte Ltd
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

defmodule OmiseGO.API.EthereumEventListener.Core do
  @moduledoc """
  Functional core of event listener
  """

  defstruct last_event_block: 1,
            block_finality_margin: 10,
            max_blocks_in_fetch: 5,
            get_events_interval: 60_000,
            get_ethereum_events_callback: nil,
            process_events_callback: nil

  def get_events_block_range(
        %__MODULE__{
          last_event_block: last_event_block,
          block_finality_margin: block_finality_margin,
          max_blocks_in_fetch: max_blocks_in_fetch,
          get_events_interval: get_events_interval
        } = state,
        current_ethereum_block
      ) do
    max_block = current_ethereum_block - block_finality_margin

    cond do
      max_block <= last_event_block ->
        {:no_blocks_with_event, state, get_events_interval}

      last_event_block + max_blocks_in_fetch < max_block ->
        next_last_event_block = last_event_block + max_blocks_in_fetch
        state = %{state | last_event_block: next_last_event_block}
        {:ok, state, 0, last_event_block + 1, next_last_event_block}

      true ->
        state = %{state | last_event_block: max_block}
        {:ok, state, get_events_interval, last_event_block + 1, max_block}
    end
  end
end
