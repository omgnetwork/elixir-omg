# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.ChildChain.BlockQueue.GasPriceCalculatorTest do
  @moduledoc false
  use ExUnitFixtures
  use ExUnit.Case, async: true

  import OMG.ChildChain.BlockTestHelper

  alias OMG.ChildChain.BlockQueue.GasPriceCalculator
  alias OMG.ChildChain.BlockQueue.GasPriceAdjustment

  @child_block_interval 1000

  doctest OMG.ChildChain.BlockQueue.GasPriceCalculator

  describe "adjust_gas_price/1" do
    test "initializes the gas adj with the parent height and last mined block" do
      state = %{
        formed_child_block_num: 10_000,
        child_block_interval: 1_000,
        mined_child_block_num: 10_000,
        parent_height: 8,
        gas_price_to_use: 1,
        gas_price_adj_params: %GasPriceAdjustment{last_block_mined: nil}
      }

      assert GasPriceCalculator.adjust_gas_price(state) == %{
        state | gas_price_adj_params: %GasPriceAdjustment{last_block_mined: {8, 10_000}}
      }
    end

    test "returns the passed state when the parent height is inferior or equal to the last checked height" do
      state = %{
        formed_child_block_num: 10_000,
        mined_child_block_num: 5_000,
        child_block_interval: 1_000,
        blocks: get_blocks(10),
        parent_height: 8,
        last_parent_height: 8,
        gas_price_to_use: 1,
        gas_price_adj_params: %GasPriceAdjustment{last_block_mined: {8, 8_000}}
      }

      assert GasPriceCalculator.adjust_gas_price(state) == state
    end

    test "returns the passed state when there's no block to mine" do
      state = %{
        blocks: get_blocks(10),
        formed_child_block_num: 10_000,
        mined_child_block_num: 10_000,
        child_block_interval: 1_000,
        parent_height: 10,
        last_parent_height: 8,
        gas_price_to_use: 1,
        gas_price_adj_params: %GasPriceAdjustment{last_block_mined: {8, 8_000}}
      }

      assert GasPriceCalculator.adjust_gas_price(state) == state
    end

    # gas price #1: raising factor when blocks needs to be mined, eth blocks gap filled, and no new blocks mined
    test "sets the gas_price_to_use to the given gas_price_to_use * the raising factor (default 2.0)
          when blocks need to be mined, the eth block gap is filled and no new blocks were mined" do
      state = %{
        blocks: get_blocks(10),
        formed_child_block_num: 10_000,
        mined_child_block_num: 6_000,
        child_block_interval: 1_000,
        parent_height: 10,
        last_parent_height: 8,
        gas_price_to_use: 1_000,
        gas_price_adj_params: %GasPriceAdjustment{
          max_gas_price: 10_000,
          last_block_mined: {8, 8_000}
        }
      }

      assert GasPriceCalculator.adjust_gas_price(state) == %{
        state |
          gas_price_to_use: 2_000, # 1_000 * 2
          last_parent_height: 10
      }
    end

    # gas price #2: lowering factor when not (blocks needs to be mined, eth blocks gap filled, and no new blocks mined)
    test "sets the gas_price_to_use to the given gas_price_to_use * the lowering factor (default 0.9)
          when blocks don't need to be mined" do
      state = %{
        blocks: get_blocks(11),
        formed_child_block_num: 11_000,
        mined_child_block_num: 10_000,
        child_block_interval: 1_000,
        parent_height: 10,
        last_parent_height: 9,
        gas_price_to_use: 1_000,
        gas_price_adj_params: %GasPriceAdjustment{
          max_gas_price: 10_000,
          last_block_mined: {100, 10_000}
        }
      }

      assert GasPriceCalculator.adjust_gas_price(state) == %{
        state |
          gas_price_to_use: 900,
          last_parent_height: 10
      }
    end

    # gas price #4: last_checked_mined_block_num < mined_child_block_num -> {parent_height, mined_child_block_num}

    # gas price #3: max gas price defined in adjustment
    test "sets the max gas price (1_000) when lower than the raising factor * the given gas price to use (1_200)" do
      state = %{
        blocks: get_blocks(10),
        formed_child_block_num: 10_000,
        mined_child_block_num: 6_000,
        child_block_interval: 1_000,
        parent_height: 10,
        last_parent_height: 8,
        gas_price_to_use: 1_200,
        gas_price_adj_params: %GasPriceAdjustment{
          max_gas_price: 1000,
          last_block_mined: {8, 8_000}
        }
      }

      assert GasPriceCalculator.adjust_gas_price(state) == %{
        state |
          gas_price_to_use: 1000,
          last_parent_height: 10,
          gas_price_adj_params: %GasPriceAdjustment{
            max_gas_price: 1_000,
            last_block_mined: {8, 8_000}
          }
      }
    end


  end
end
