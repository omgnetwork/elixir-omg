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

defmodule OMG.ChildChain.GasPrice do
  @moduledoc """
  Suggests gas prices based on different strategies.
  """
  alias OMG.ChildChain.Configuration
  alias OMG.ChildChain.GasPrice.PoissonGasStrategy
  alias OMG.ChildChain.GasPrice.LegacyGasStrategy

  @type price() :: pos_integer()

  @doc """
  Trigger gas price recalculations for all strategies.
  """
  @spec recalculate_all(map(), pos_integer(), pos_integer(), pos_integer(), pos_integer()) :: :ok
  def recalculate_all(blocks, parent_height, mined_child_block_num, formed_child_block_num, child_block_interval) do
    _ = PoissonGasStrategy.recalculate()

    _ =
      LegacyGasStrategy.recalculate(
        blocks,
        parent_height,
        mined_child_block_num,
        formed_child_block_num,
        child_block_interval
      )

    :ok
  end

  @doc """
  Suggests the optimal gas price using the configured strategy.
  """
  @spec suggest() :: {:ok, price()}
  def suggest() do
    Configuration.block_submit_gas_price_strategy().get_price()
  end
end
