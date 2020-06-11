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

defmodule OMG.ChildChain.GasPrice.PoissonGasStrategy do
  @moduledoc """
  Suggests gas prices based on Poisson regression model (also used by EthGasStation).

  Ported from https://github.com/ethgasstation/gasstation-express-oracle/blob/master/gasExpress.py
  """
  require Logger
  alias OMG.ChildChain.GasPrice
  alias OMG.ChildChain.GasPrice.Strategy
  alias OMG.ChildChain.GasPrice.PoissonGasStrategy.Analyzer

  @behaviour Strategy

  @doc """
  Starts the Poisson regression strategy.
  """
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    Analyzer.start_link(opts)
  end

  @doc """
  Suggests the optimal gas price.
  """
  @impl Strategy
  @spec get_price() :: GasPrice.t()
  def get_price() do
    GenServer.call(Analyzer, :get_price)
  end

  @doc """
  A stub that handles the recalculation trigger.

  Since Poisson regression strategy recalculates based on its interval and not a recalculation
  triggered by the `recalculate/1`'s caller, this function simply returns `:ok` without any computation.

  To get the price, use `get_price/0` instead.
  """
  @impl Strategy
  @spec recalculate(Keyword.t()) :: :ok
  def recalculate(_params) do
    :ok
  end
end
