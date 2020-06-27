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

defmodule OMG.ChildChain.GasPrice.Strategy.PoissonGasStrategy do
  @moduledoc """
  Suggests gas prices based on Poisson regression model (also used by EthGasStation).

  Requires `OMG.ChildChain.GasPrice.Strategy.History` running.

  Ported from https://github.com/ethgasstation/gasstation-express-oracle/blob/master/gasExpress.py
  """
  use GenServer
  require Logger
  alias OMG.ChildChain.GasPrice.History
  alias OMG.ChildChain.GasPrice.Strategy
  alias OMG.ChildChain.GasPrice.Strategy.PoissonGasStrategy.Algorithm

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

  @type error() :: {:error, :all_empty_blocks}

  defstruct prices: %{
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

  @target_threshold :fast

  @behaviour Strategy

  @doc """
  Starts the Poisson regression strategy.
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
    prices = do_recalculate()

    _ = Logger.info("#{__MODULE__}: History updated. Prices recalculated to: #{inspect(prices)}")
    {:noreply, %{state | prices: prices}}
  end

  #
  # Internal implementations
  #

  defp do_recalculate() do
    price_history = History.all()

    {hash_percentages, lowest_min_price, highest_min_price} = Algorithm.analyze_blocks(price_history)
    prediction_table = Algorithm.make_prediction_table(hash_percentages, lowest_min_price, highest_min_price)
    Algorithm.get_recommendations(@thresholds, prediction_table)
  end
end
