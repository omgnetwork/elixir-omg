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

defmodule OMG.ChildChain.GasPrice.GasPriceSupervisor do
  @moduledoc """
  Supervises services related to gas price.
  """
  use Supervisor
  require Logger

  alias OMG.Bus
  alias OMG.ChildChain.GasPrice.History
  alias OMG.ChildChain.GasPrice.Strategy.BlockPercentileGasStrategy
  alias OMG.ChildChain.GasPrice.Strategy.LegacyGasStrategy
  alias OMG.ChildChain.GasPrice.Strategy.PoissonGasStrategy

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(init_arg) do
    num_blocks = Keyword.fetch!(init_arg, :num_blocks)
    max_gas_price = Keyword.fetch!(init_arg, :max_gas_price)
    ethereum_url = Keyword.fetch!(init_arg, :ethereum_url)

    children = [
      {History, [event_bus: Bus, num_blocks: num_blocks, ethereum_url: ethereum_url]},
      # Unfortunately LegacyGasStrategy cannot rely on its caller to enforce `max_gas_price`
      # because the strategy can keep doubling the price through the roof and take forever
      # to get back down below `max_gas_price` without its own ceiling.
      {LegacyGasStrategy, [max_gas_price: max_gas_price]},
      # Other strategies don't need `max_gas_price` at the algorithm level because they depend
      # on historical statistics and not an uncapped multiplier.
      {BlockPercentileGasStrategy, []},
      {PoissonGasStrategy, []}
    ]

    _ = Logger.info("Starting #{__MODULE__}")
    Supervisor.init(children, strategy: :one_for_one)
  end
end
