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

defmodule OMG.ChildChain.BlockQueue.GasPriceAdjustment do
  @moduledoc """
  Encapsulates the Eth gas price adjustment strategy parameters into its own structure
  """

  defstruct eth_gap_without_child_blocks: 2,
            gas_price_lowering_factor: 0.9,
            gas_price_raising_factor: 2.0,
            max_gas_price: 20_000_000_000,
            last_block_mined: nil

  @type t() :: %__MODULE__{
          # minimum blocks count where child blocks are not mined therefore gas price needs to be increased
          eth_gap_without_child_blocks: pos_integer(),
          # the factor the gas price will be decreased by
          gas_price_lowering_factor: float(),
          # the factor the gas price will be increased by
          gas_price_raising_factor: float(),
          # maximum gas price above which raising has no effect, limits the gas price calculation
          max_gas_price: pos_integer(),
          # remembers ethereum height and last child block mined, used for the gas price calculation
          last_block_mined: tuple() | nil
        }

  def with(state, last_checked_parent_height, last_checked_mined_child_block_num) do
    %{state | last_block_mined: {last_checked_parent_height, last_checked_mined_child_block_num}}
  end
end
