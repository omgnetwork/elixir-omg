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

defmodule OMG.Watcher.ExitValidator.Core do
  @moduledoc """
  Functional core of exit validator
  """

  defstruct last_exit_block_height: nil, margin_on_synced_block: 0, update_key: nil, utxo_exists_callback: nil

  @spec get_exits_block_range(%__MODULE__{}, pos_integer) ::
          {pos_integer, pos_integer, %__MODULE__{}, list()} | :empty_range
  def get_exits_block_range(
        %__MODULE__{
          last_exit_block_height: last_exit_block_height,
          margin_on_synced_block: margin_on_synced_block,
          update_key: update_key
        } = state,
        synced_eth_block_height
      )
      when synced_eth_block_height != nil do
    max_upper_range = synced_eth_block_height - margin_on_synced_block

    if last_exit_block_height >= max_upper_range do
      :empty_range
    else
      state = %{state | last_exit_block_height: max_upper_range}

      {last_exit_block_height + 1, max_upper_range, state, [{:put, update_key, max_upper_range}]}
    end
  end
end
