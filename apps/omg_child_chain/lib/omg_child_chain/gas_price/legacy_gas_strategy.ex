# Copyright 2020 OmiseGO Pte Ltd
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

defmodule OMG.ChildChain.GasPrice.LegacyGasStrategy do
  @moduledoc """
  Determines the optimal gas price based on the childchain's legacy strategy.

  ### Gas price selection

  The mechanism employed is minimalistic, aiming at:
    - pushing formed block submissions as reliably as possible, avoiding delayed mining of submissions as much as possible
    - saving Ether only when certain that we're overpaying
    - being simple and avoiding any external factors driving the mechanism

  The mechanics goes as follows:

  If:
    - we've got a new child block formed, whose submission isn't yet mined and
    - it's been more than 2 (`eth_gap_without_child_blocks`) root chain blocks
    since a submission has last been seen mined

  the gas price is raised by a factor of 2 (`gas_price_raising_factor`)

  **NOTE** there's also an upper limit for the gas price (`max_gas_price`)

  If:
    - we've got a new child block formed, whose submission isn't yet mined and
    - it's been no more than 2 (`eth_gap_without_child_blocks`) root chain blocks
    since a submission has last been seen mined

  the gas price is lowered by a factor of 0.9 ('gas_price_lowering_factor')
  """
  use GenServer
  require Logger

  alias OMG.ChildChain.GasPrice.Strategy

  @behaviour Strategy

  @type t() :: %__MODULE__{
          # minimum blocks count where child blocks are not mined therefore gas price needs to be increased
          eth_gap_without_child_blocks: pos_integer(),
          # the factor the gas price will be decreased by
          gas_price_lowering_factor: float(),
          # the factor the gas price will be increased by
          gas_price_raising_factor: float(),
          # last gas price calculated
          gas_price_to_use: pos_integer(),
          # maximum gas price above which raising has no effect, limits the gas price calculation
          max_gas_price: pos_integer(),
          # last parent height successfully evaluated for gas price
          last_parent_height: pos_integer(),
          # last child block mined
          last_mined_child_block_num: pos_integer()
        }

  defstruct eth_gap_without_child_blocks: 2,
            gas_price_lowering_factor: 0.9,
            gas_price_raising_factor: 2.0,
            gas_price_to_use: 20_000_000_000,
            max_gas_price: 20_000_000_000,
            last_block_mined: 0,
            last_parent_height: 0,
            last_mined_child_block_num: 0

  @doc """
  Starts the legacy gas price strategy.
  """
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc false
  @impl GenServer
  def init(args) do
    state = %__MODULE__{
      max_gas_price: Keyword.fetch!(args, :max_gas_price)
    }

    {:ok, state}
  end

  @doc """
  Suggests the optimal gas price.
  """
  @impl Strategy
  @spec get_price() :: {:ok, GasPrice.t()}
  def get_price() do
    GenServer.call(__MODULE__, :get_price)
  end

  @doc """
  Triggers gas price recalculation.

  Returns `:ok` on success. Raises an error if a required param is missing.

  This function does not return the price. To get the price, use `get_price/0` instead.
  """
  @impl Strategy
  @spec recalculate(Keyword.t()) :: :ok | no_return()
  def recalculate(params) do
    latest = %{
      blocks: Keyword.fetch!(params, :blocks),
      parent_height: Keyword.fetch!(params, :parent_height),
      mined_child_block_num: Keyword.fetch!(params, :mined_child_block_num),
      formed_child_block_num: Keyword.fetch!(params, :formed_child_block_num),
      child_block_interval: Keyword.fetch!(params, :child_block_interval)
    }

    # Using `call()` here as the legacy algorithm requires a blocking operation.
    # Its result needs to be applied to the upcoming block immediately.
    GenServer.call(__MODULE__, {:recalculate, latest})
  end

  @doc false
  @impl GenServer
  def handle_call(:get_price, _, state) do
    {:reply, {:ok, state.gas_price_to_use}, state}
  end

  @doc false
  @impl GenServer
  def handle_call({:recalculate, latest}, _, state) do
    {:reply, :ok, do_recalculate(latest, state)}
  end

  defp do_recalculate(latest, state) do
    cond do
      latest.parent_height - state.last_parent_height < state.eth_gap_without_child_blocks ->
        state

      !blocks_to_mine(latest.blocks, latest.mined_child_block_num, latest.formed_child_block_num, latest.child_block_interval) ->
        state

      true ->
        gas_price_to_use =
          calculate_gas_price(
            latest.mined_child_block_num,
            latest.formed_child_block_num,
            state.last_mined_child_block_num,
            state.gas_price_to_use,
            state.gas_price_raising_factor,
            state.gas_price_lowering_factor,
            state.max_gas_price
          )

        state = Map.update!(state, :gas_price_to_use, gas_price_to_use)
        _ = Logger.debug("using new gas price '#{inspect(state.gas_price_to_use)}'")

        case state.last_mined_child_block_num < latest.mined_child_block_num do
          true ->
            state
            |> Map.update!(:last_parent_height, latest.parent_height)
            |> Map.update!(:last_mined_child_block_num, latest.mined_child_block_num)

          false ->
            state
        end
    end
  end

  # Calculates the gas price basing on simple strategy to raise the gas price by gas_price_raising_factor
  # when gap of mined parent blocks is growing and droping the price by gas_price_lowering_factor otherwise
  @spec calculate_gas_price(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          pos_integer(),
          float(),
          float(),
          pos_integer()
        ) :: pos_integer()
  defp calculate_gas_price(
         mined_child_block_num,
         formed_child_block_num,
         last_mined_child_block_num,
         gas_price_to_use,
         raising_factor,
         lowering_factor,
         max_gas_price
       ) do
    blocks_needs_be_mined? = blocks_needs_be_mined?(formed_child_block_num, mined_child_block_num)
    new_blocks_mined? = new_blocks_mined?(mined_child_block_num, last_mined_child_block_num)

    multiplier =
      case {blocks_needs_be_mined?, new_blocks_mined?} do
        {false, _} -> 1.0
        {true, false} -> raising_factor
        {_, true} -> lowering_factor
      end

    Kernel.min(max_gas_price, Kernel.round(multiplier * gas_price_to_use))
  end

  defp blocks_needs_be_mined?(formed_child_block_num, mined_child_block_num) do
    formed_child_block_num > mined_child_block_num
  end

  defp new_blocks_mined?(mined_child_block_num, last_mined_block_num) do
    mined_child_block_num > last_mined_block_num
  end

  defp blocks_to_mine(blocks, mined_child_block_num, child_block_interval, formed_child_block_num) do
    Enum.find(blocks, fn {blknum, _} ->
      mined_child_block_num + child_block_interval <= blknum and blknum <= formed_child_block_num
    end)
  end
end
