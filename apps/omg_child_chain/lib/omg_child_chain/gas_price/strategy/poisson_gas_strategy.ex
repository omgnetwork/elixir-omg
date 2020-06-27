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
    sorted_min_prices = History.all() |> filter_min() |> Enum.sort()

    # Handles when all blocks are empty (possible on local chain and low traffic testnets)
    case length(sorted_min_prices) do
      0 ->
        {:error, :all_empty_blocks}

      block_count ->
        Enum.map(@thresholds, fn {_name, value} ->
          position = floor(block_count * value / 100) - 1
          Enum.at(sorted_min_prices, position)
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

  #
  # Internal implementations
  #

  # Port over https://github.com/ethgasstation/gasstation-express-oracle/blob/master/gasExpress.py
  #
  # def make_predictTable(block, alltx, hashpower, avg_timemined):
  #     predictTable = pd.DataFrame({'gasprice' :  range(10, 1010, 10)})
  #     ptable2 = pd.DataFrame({'gasprice' : range(0, 10, 1)})
  #     predictTable = predictTable.append(ptable2).reset_index(drop=True)
  #     predictTable = predictTable.sort_values('gasprice').reset_index(drop=True)
  #     predictTable['hashpower_accepting'] = predictTable['gasprice'].apply(get_hpa, args=(hashpower,))
  #     return(predictTable)
  #
  # def get_hpa(gasprice, hashpower):
  #     """gets the hash power accpeting the gas price over last 200 blocks"""
  #     hpa = hashpower.loc[gasprice >= hashpower.index, 'hashp_pct']
  #     if gasprice > hashpower.index.max():
  #         hpa = 100
  #     elif gasprice < hashpower.index.min():
  #         hpa = 0
  #     else:
  #         hpa = hpa.max()
  #     return int(hpa)
  #
  # def analyze_last200blocks(block, blockdata):
  #     recent_blocks = blockdata.loc[blockdata['block_number'] > (block-200), ['mingasprice', 'block_number']]
  #     #create hashpower accepting dataframe based on mingasprice accepted in block
  #     hashpower = recent_blocks.groupby('mingasprice').count()
  #     hashpower = hashpower.rename(columns={'block_number': 'count'})
  #     hashpower['cum_blocks'] = hashpower['count'].cumsum()
  #     totalblocks = hashpower['count'].sum()
  #     hashpower['hashp_pct'] = hashpower['cum_blocks']/totalblocks*100
  #     #get avg blockinterval time
  #     blockinterval = recent_blocks.sort_values('block_number').diff()
  #     blockinterval.loc[blockinterval['block_number'] > 1, 'time_mined'] = np.nan
  #     blockinterval.loc[blockinterval['time_mined']< 0, 'time_mined'] = np.nan
  #     avg_timemined = blockinterval['time_mined'].mean()
  #     if np.isnan(avg_timemined):
  #         avg_timemined = 15
  #     return(hashpower, avg_timemined)
  #
  # def get_fast():
  #     series = prediction_table.loc[prediction_table['hashpower_accepting'] >= FAST, 'gasprice']
  #     fastest = series.min()
  #     return float(fastest)
  #
  # def get_fastest():
  #     hpmax = prediction_table['hashpower_accepting'].max()
  #     fastest = prediction_table.loc[prediction_table['hashpower_accepting'] == hpmax, 'gasprice'].values[0]
  #     return float(fastest)
end
