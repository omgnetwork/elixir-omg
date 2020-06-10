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
  use GenServer
  require Logger

  alias OMG.ChildChain.GasPrice

  @recalculate_interval_ms 60_000

  @type t() :: %__MODULE__{
          gas_price_to_use: pos_integer(),
          max_gas_price: pos_integer()
        }

  defstruct gas_price_to_use: 20_000_000_000,
            max_gas_price: 20_000_000_000

  @doc """
  Starts the EthGasStation strategy.
  """
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc false
  def init(args) do
    state = %__MODULE__{
      max_gas_price: Keyword.fetch!(args, :max_gas_price)
    }

    {:ok, state, {:continue, :start_recalculate}}
  end

  @doc false
  def handle_continue(:start_recalculate, state) do
    _ = send(self(), :recalculate)
    {:ok, _} = :timer.send_interval(@recalculate_interval_ms, self(), :recalculate)

    _ = Logger.info("Started #{inspect(__MODULE__)}: #{inspect(state)}")
    {:noreply, state}
  end

  @doc """
  Suggests the optimal gas price.
  """
  @spec get_price() :: GasPrice.price()
  def get_price() do
    GenServer.call(__MODULE__, :get_price)
  end

  @doc """
  Triggers gas price recalculation.

  This function does not return the price. To get the price, use `get_price/0` instead.
  """
  @spec recalculate() :: :ok
  def recalculate() do
    # Poisson regression strategy recalculates based on its interval, not a recalculation trigger
    # by the BlockQueue. So it immediately returns :ok
    :ok
  end

  @doc false
  def handle_call(:get_price, state) do
    {:reply, {:ok, state.gas_price_to_use}, state}
  end

  @doc false
  def handle_info(:recalculate, state) do
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

    {:noreply, state}
  end
end
