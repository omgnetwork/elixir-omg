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

defmodule OMG.ChildChain.BlockQueue.GasPriceCalculator do
  @moduledoc """

  """

  alias OMG.ChildChain.BlockQueue
  alias OMG.ChildChain.BlockQueue.BlockQueueState
  alias OMG.ChildChain.BlockQueue.GasPriceAdjustment

  use OMG.Utils.LoggerExt

  @zero_bytes32 <<0::size(256)>>

  @type submit_result_t() :: {:ok, <<_::256>>} | {:error, map}

  # Updates gas price to use basing on :calculate_gas_price function, updates current parent height
  # and last mined child block number in the state which used by gas price calculations
  @spec adjust_gas_price(BlockQueueState.t()) :: BlockQueueState.t()
  def adjust_gas_price(
        %BlockQueueState{gas_price_adj_params: %GasPriceAdjustment{last_block_mined: nil} = gas_params} = state
      ) do
    # initializes last block mined
    %{
      state
      | gas_price_adj_params: GasPriceAdjustment.with(gas_params, state.parent_height, state.mined_child_block_num)
    }
  end

  def adjust_gas_price(
        %BlockQueueState{blocks: blocks, parent_height: parent_height, last_parent_height: last_parent_height} = state
      ) do
    case parent_height <= last_parent_height || !Enum.find(blocks, to_mined_block_filter(state)) do
      true ->
        state

      false ->
        new_gas_price = calculate_gas_price(state)
        _ = Logger.debug("using new gas price '#{inspect(new_gas_price)}'")

        state
        |> Map.put(:gas_price_to_use, new_gas_price)
        |> update_last_checked_mined_block_num()
        |> Map.put(:last_parent_height, parent_height)
    end
  end

  # Updates the state with information about last parent height and mined child block number
  @spec update_last_checked_mined_block_num(BlockQueueState.t()) :: BlockQueueState.t()
  defp update_last_checked_mined_block_num(
         %BlockQueueState{
           parent_height: parent_height,
           mined_child_block_num: mined_child_block_num,
           gas_price_adj_params: %GasPriceAdjustment{
             last_block_mined: {_lastechecked_parent_height, lastchecked_mined_block_num}
           }
         } = state
       ) do
    if lastchecked_mined_block_num < mined_child_block_num do
      %BlockQueueState{
        state
        | gas_price_adj_params:
            GasPriceAdjustment.with(state.gas_price_adj_params, parent_height, mined_child_block_num)
      }
    else
      state
    end
  end

  # Calculates the gas price basing on simple strategy to raise the gas price by gas_price_raising_factor
  # when gap of mined parent blocks is growing and droping the price by gas_price_lowering_factor otherwise
  @spec calculate_gas_price(BlockQueueState.t()) :: pos_integer()
  defp calculate_gas_price(
         %BlockQueueState{
           gas_price_to_use: gas_price_to_use,
           gas_price_adj_params: %GasPriceAdjustment{max_gas_price: max_gas_price}
         } = state
       ) do
    Kernel.min(
      max_gas_price,
      Kernel.round(calculate_multiplier(state) * gas_price_to_use)
    )
  end

  defp calculate_multiplier(%BlockQueueState{
         formed_child_block_num: formed_child_block_num,
         mined_child_block_num: mined_child_block_num,
         gas_price_to_use: gas_price_to_use,
         parent_height: parent_height,
         gas_price_adj_params: %GasPriceAdjustment{
           gas_price_lowering_factor: gas_price_lowering_factor,
           gas_price_raising_factor: gas_price_raising_factor,
           eth_gap_without_child_blocks: eth_gap_without_child_blocks,
           max_gas_price: max_gas_price,
           last_block_mined: {lastchecked_parent_height, lastchecked_mined_block_num}
         }
       }) do
    with true <- blocks_needs_be_mined?(formed_child_block_num, mined_child_block_num),
         true <- eth_blocks_gap_filled?(parent_height, lastchecked_parent_height, eth_gap_without_child_blocks),
         false <- new_blocks_mined?(mined_child_block_num, lastchecked_mined_block_num) do
      gas_price_raising_factor
    else
      _ ->
        gas_price_lowering_factor
    end
  end

  defp blocks_needs_be_mined?(formed_child_block_num, mined_child_block_num) do
    formed_child_block_num > mined_child_block_num
  end

  defp eth_blocks_gap_filled?(parent_height, last_height, eth_gap_without_child_blocks) do
    parent_height - last_height >= eth_gap_without_child_blocks
  end

  defp new_blocks_mined?(mined_child_block_num, last_mined_block_num) do
    mined_child_block_num > last_mined_block_num
  end

  # TTODO: Extract to other module?
  @spec first_to_mined(BlockQueueState.t()) :: pos_integer()
  def first_to_mined(%{mined_child_block_num: mined, child_block_interval: interval}), do: mined + interval

  @spec to_mined_block_filter(BlockQueueState.t()) :: ({pos_integer, BlockSubmission.t()} -> boolean)
  def to_mined_block_filter(%{formed_child_block_num: formed} = state) do
    fn {blknum, _} ->
      first_to_mined(state) <= blknum and blknum <= formed
    end
  end
end
