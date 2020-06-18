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

defmodule OMG.ChildChain.GasPrice.Supervisor do
  @moduledoc """
  Supervises services related to gas price.
  """
  use Supervisor
  require Logger

  alias OMG.Bus
  alias OMG.ChildChain.Configuration
  alias OMG.ChildChain.GasPrice.History
  alias OMG.ChildChain.GasPrice.Strategy.BlockPercentileGasStrategy
  alias OMG.ChildChain.GasPrice.Strategy.LegacyGasStrategy
  alias OMG.ChildChain.GasPrice.Strategy.PoissonGasStrategy

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(init_arg) do
    children = children(init_arg)

    _ = Logger.info("Starting #{__MODULE__}")
    Supervisor.init(children, [strategy: :one_for_one])
  end

  defp children(args) do
    num_blocks = Configuration.get(:block_submit_gas_price_history_blocks)
    max_gas_price = Configuration.get(:block_submit_max_gas_price)

    [
      {History, [event_bus: OMG.Bus, num_blocks: num_blocks]},
      {LegacyGasStrategy, [max_gas_price: max_gas_price]},
      {BlockPercentileGasStrategy, []},
      {PoissonGasStrategy, []}
    ]
  end
end
