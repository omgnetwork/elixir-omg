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

  ## Usage

  Prepare the gas price configurations:

      config :omg_child_chain,
        # ...
        block_submit_gas_price_strategy: OMG.ChildChain.GasPrice.Strategy.LegacyGasStrategy,
        block_submit_max_gas_price: 20_000_000_000,
        block_submit_gas_price_history_blocks: 200

  Include `OMG.ChildChain.GasPrice.GasPriceSupervisor` in the supervision tree:

      children = [
        {GasPriceSupervisor, [num_blocks: gas_price_history_blocks, max_gas_price: max_gas_price]}
      ]

      Supervisor.init(children, strategy: :one_for_one)

  Then, call `OMG.ChildChain.GasPrice.get_price()` to get the gas price suggestion.
  """
  require Logger
  alias OMG.ChildChain.GasPrice.Strategy.BlockPercentileGasStrategy
  alias OMG.ChildChain.GasPrice.Strategy.LegacyGasStrategy
  alias OMG.ChildChain.GasPrice.Strategy.PoissonGasStrategy

  @strategies [BlockPercentileGasStrategy, LegacyGasStrategy, PoissonGasStrategy]

  @doc """
  Trigger gas price recalculations for all strategies.
  """
  @spec recalculate_all(Keyword.t()) :: :ok
  def recalculate_all(params) do
    Enum.each(@strategies, fn strategy -> :ok = strategy.recalculate(params) end)
  end

  @doc """
  Suggests the optimal gas price using the provided target strategy.
  """
  @spec get_price(module()) :: {:ok, pos_integer()} | {:error, :no_gas_price_history}
  def get_price(target_strategy) do
    price_suggestions =
      Enum.reduce(@strategies, %{}, fn strategy, suggestions ->
        Map.put(suggestions, strategy, strategy.get_price())
      end)

    _ = Logger.info("#{__MODULE__}: All price suggestions: #{inspect(price_suggestions)}")
    price_suggestions[target_strategy]
  end
end
