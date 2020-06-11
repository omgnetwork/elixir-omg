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
  alias OMG.ChildChain.GasPrice.LegacyGasStrategy
  alias OMG.ChildChain.GasPrice.PoissonGasStrategy

  @type t() :: pos_integer()

  @strategies [LegacyGasStrategy, PoissonGasStrategy]

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
  @spec get_price() :: {:ok, t()}
  def get_price() do
    Configuration.block_submit_gas_price_strategy().get_price()
  end
end
