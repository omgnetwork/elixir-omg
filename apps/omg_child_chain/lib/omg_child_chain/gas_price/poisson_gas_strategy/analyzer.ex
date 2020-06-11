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

defmodule OMG.ChildChain.GasPrice.PoissonGasStrategy.Analyzer do
  @moduledoc """
  Responsible for starting the gas price history and analyzing its records
  in order to recommend an optimal gas price.
  """
  use GenServer
  require Logger

  alias OMG.ChildChain.GasPrice.PoissonGasStrategy.History

  @type t() :: %__MODULE__{
          recommended_gas_price: pos_integer(),
          max_gas_price: pos_integer(),
          analyzed_height: pos_integer()
        }

  defstruct recommended_gas_price: 20_000_000_000,
            max_gas_price: 20_000_000_000,
            analyzed_height: 0

  @doc false
  @spec start_link([max_gas_price: pos_integer(), event_bus: module()]) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  #
  # GenServer initialization
  #

  @doc false
  @impl GenServer
  def init(opts) do
    # Starts the history process where it will obtain gas price records from
    history_opts = [event_bus: Keyword.fetch!(opts, :event_bus)]
    {:ok, _pid} = History.start_link(history_opts)

    # Prepares its own state
    state = %__MODULE__{
      max_gas_price: Keyword.fetch!(opts, :max_gas_price)
    }

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
