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

  Include `OMG.ChildChain.GasPrice.GasPriceSupervisor` in the supervision tree:

      children = [
        {GasPriceSupervisor, [num_blocks: gas_price_history_blocks, max_gas_price: max_gas_price]}
      ]

      Supervisor.init(children, strategy: :one_for_one)

  Then, call `OMG.ChildChain.GasPrice.get_price()` to get the gas price suggestion.
  """
  require Logger
  alias OMG.ChildChain.Configuration
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
  Suggests the optimal gas price using the configured strategy.
  """
  @spec get_price() :: {:ok, pos_integer()} | {:error, atom()}
  def get_price() do
    price_suggestions =
      Enum.reduce(@strategies, %{}, fn strategy, suggestions ->
        Map.put(suggestions, strategy, strategy.get_price())
      end)

    _ = Logger.info("#{__MODULE__}: All price suggestions: #{inspect(price_suggestions)}")

    gas_price = price_suggestions[Configuration.block_submit_gas_price_strategy()]

    _ = Logger.info("#{__MODULE__}: Suggesting gas price: #{gas_price / 1_000_000_000} gwei.")
    gas_price
  end
end
