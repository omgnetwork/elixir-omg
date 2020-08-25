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
  alias OMG.ChildChain.GasPrice.History
  alias OMG.ChildChain.GasPrice.Strategy

  @type t() :: %__MODULE__{
          prices:
            %{
              safe_low: float(),
              standard: float(),
              fast: float(),
              fastest: float()
            }
            | error()
        }

  @type error() :: {:error, :no_gas_price_history}

  defstruct prices: %{
              safe_low: 20_000_000_000,
              standard: 20_000_000_000,
              fast: 20_000_000_000,
              fastest: 20_000_000_000
            }

  @typep thresholds() :: %{
    safe_low: non_neg_integer(),
    standard: non_neg_integer(),
    fast: non_neg_integer(),
    fastest: non_neg_integer()
  }

  @thresholds %{
    safe_low: 35,
    standard: 60,
    fast: 90,
    fastest: 100
  }

  @target_threshold :fast

  @typep recommendations() :: %{
    safe_low: float(),
    standard: float(),
    fast: float(),
    fastest: float()
  }

  @behaviour Strategy

  @doc """
  Starts the block percentile strategy.
  """
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @doc """
  Suggests the optimal gas price.
  """
  @impl Strategy
  @spec get_price() :: {:ok, pos_integer()} | error()
  def get_price() do
    GenServer.call(__MODULE__, :get_price)
  end

  @doc """
  A stub that handles the recalculation trigger.

  Since this strategy recalculates based on its interval and not a recalculation
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

    _ = Logger.info("Started #{__MODULE__}: #{inspect(state)}")
    {:ok, state}
  end

  #
  # GenServer callbacks
  #

  @doc false
  @impl GenServer
  def handle_call(:get_price, _, state) do
    price =
      case state.prices do
        {:error, _} = error ->
          error

        prices ->
          {:ok, prices[@target_threshold]}
      end

    {:reply, price, state}
  end

  @doc false
  @impl GenServer
  def handle_info({History, :updated}, state) do
    prices = calculate(History.all(), @thresholds)

    _ = Logger.info("#{__MODULE__}: History updated. Prices recalculated to: #{inspect(prices)}")
    {:noreply, %{state | prices: prices}}
  end

  #
  # Internal implementations
  #

  # Returns the recommended gas prices for each of the provided `@thresholds`. It does the following:
  #   1. For each historical block, take the minimum gas price accepted by the block
  #   2. Sort the minimum gas prices from lowest to highest prices
  #   3. Extract the gas prices at the given thresholds (in other word, the percentile)
  #
  # Edge case behaviours:
  #   1. No historical gas prices available. Returns `{:error, :no_gas_price_history}`.
  #      Prices continue to be fetched and recalculated on the same regular basis.
  #   2. Too few historical gas prices. Calculation will be done on as much as the price data is available.
  @spec calculate(History.t(), thresholds()) :: recommendations() | {:error, :no_gas_price_history}
  defp calculate(history, thresholds) do
    sorted_min_prices = history |> filter_min() |> Enum.sort()

    # Handles when all blocks are empty (possible on local chain and low traffic testnets)
    case length(sorted_min_prices) do
      0 ->
        {:error, :no_gas_price_history}

      block_count ->
        Enum.map(thresholds, fn {threshold_name, value} ->
          position = floor(block_count * value / 100) - 1
          {threshold_name, Enum.at(sorted_min_prices, position)}
        end)
    end
  end

  defp filter_min(prices) do
    Enum.reduce(prices, [], fn
      # Skips empty blocks (possible in local chain and low traffic testnets)
      {_height, [], _timestamp}, acc -> acc
      {_height, prices, _timestamp}, acc -> [Enum.min(prices) | acc]
    end)
  end
end
