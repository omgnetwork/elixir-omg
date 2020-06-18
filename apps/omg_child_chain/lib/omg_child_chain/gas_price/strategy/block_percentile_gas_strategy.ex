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

defmodule OMG.ChildChain.GasPrice.Strategy.BlockPercentileGasStrategy do
  @moduledoc """
  Suggests gas prices based on the percentile of blocks that accepted as the minimum gas price.

  Requires `OMG.ChildChain.GasPrice.Strategy.History` running.
  """
  use GenServer
  require Logger
  alias OMG.ChildChain.GasPrice
  alias OMG.ChildChain.GasPrice.History
  alias OMG.ChildChain.GasPrice.Strategy

  @type t() :: %__MODULE__{
          recommendations: %{
            safe_low: float(),
            standard: float(),
            fast: float(),
            fastest: float()
          }
        }

  defstruct recommendations: %{
              safe_low: 20_000_000_000,
              standard: 20_000_000_000,
              fast: 20_000_000_000,
              fastest: 20_000_000_000
            }

  @thresholds %{
    safe_low: 35,
    standard: 60,
    fast: 90,
    fastest: 100
  }

  @behaviour Strategy

  @doc """
  Starts the Poisson regression strategy.
  """
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Suggests the optimal gas price.
  """
  @impl Strategy
  @spec get_price() :: GasPrice.t()
  def get_price() do
    GenServer.call(__MODULE__, :get_price)
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

  #
  # GenServer initialization
  #

  @doc false
  @impl GenServer
  def init(_init_arg) do
    _ = History.subscribe(self())
    state = %__MODULE__{}

    _ = Logger.info("Started #{inspect(__MODULE__)}: #{inspect(state)}")
    {:ok, state}
  end

  #
  # GenServer callbacks
  #

  @doc false
  @impl GenServer
  def handle_call(:get_price, _, state) do
    {:reply, {:ok, state.recommended_gas_price}, state}
  end

  @doc false
  @impl GenServer
  def handle_info({History, :updated}, state) do
    recommendations = do_recalculate()

    {:noreply, %{state | recommendations: recommendations}}
  end

  #
  # Internal implementations
  #

  defp do_recalculate() do
    sorted_min_prices =
      History.all()
      |> Enum.map(fn {_height, prices, _timestamp} -> Enum.min(prices) end)
      |> Enum.sort()

    block_count = length(sorted_min_prices)

    Enum.map(@thresholds, fn value ->
      position = floor(block_count * value / 100) - 1
      Enum.at(sorted_min_prices, position)
    end)
  end
end
