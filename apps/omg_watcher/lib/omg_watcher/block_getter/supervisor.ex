# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule OMG.Watcher.BlockGetter.Supervisor do
  @moduledoc """
  This supervisor takes care of BlockGetter and State processes.
  In case one process fails, this supervisor's role is to restore consistent state
  """
  use Supervisor
  use OMG.Utils.LoggerExt
  alias OMG.Watcher.BlockGetter

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    contract_deployment_height = Keyword.fetch!(args, :contract_deployment_height)
    child_block_interval = OMG.Eth.Configuration.child_block_interval()
    block_getter_reorg_margin = OMG.Watcher.Configuration.block_getter_reorg_margin()
    maximum_block_withholding_time_ms = OMG.Watcher.Configuration.maximum_block_withholding_time_ms()
    maximum_number_of_unapplied_blocks = OMG.Watcher.Configuration.maximum_number_of_unapplied_blocks()
    block_getter_loops_interval_ms = OMG.Watcher.Configuration.block_getter_loops_interval_ms()
    metrics_collection_interval = OMG.Watcher.Configuration.metrics_collection_interval()
    child_chain_url = OMG.Watcher.Configuration.child_chain_url()
    contracts = OMG.Eth.Configuration.contracts()
    fee_claimer_address = Base.decode16!("DEAD000000000000000000000000000000000000")
    # State and Block Getter are linked, because they must restore their state to the last stored state
    # If Block Getter fails, it starts from the last checkpoint while State might have had executed some transactions
    # such a situation will cause error when trying to execute already executed transaction

    children = [
      # NOTE: Watcher doesn't need the actual fee claimer address
      {OMG.State,
       [
         fee_claimer_address: fee_claimer_address,
         child_block_interval: child_block_interval,
         metrics_collection_interval: metrics_collection_interval
       ]},
      %{
        id: BlockGetter,
        start:
          {BlockGetter, :start_link,
           [
             [
               child_block_interval: child_block_interval,
               block_getter_reorg_margin: block_getter_reorg_margin,
               maximum_block_withholding_time_ms: maximum_block_withholding_time_ms,
               maximum_number_of_unapplied_blocks: maximum_number_of_unapplied_blocks,
               metrics_collection_interval: metrics_collection_interval,
               block_getter_loops_interval_ms: block_getter_loops_interval_ms,
               child_chain_url: child_chain_url,
               contract_deployment_height: contract_deployment_height,
               contracts: contracts
             ]
           ]},
        restart: :transient
      }
    ]

    opts = [strategy: :one_for_all]

    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    Supervisor.init(children, opts)
  end
end
