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

  alias OMG.ChildChain.GasPrice.History
  alias OMG.ChildChain.GasPrice.Strategy.BlockPercentileGasStrategy
  alias OMG.ChildChain.GasPrice.Strategy.LegacyGasStrategy
  alias OMG.ChildChain.GasPrice.Strategy.PoissonGasStrategy

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(init_arg) do
    args = children(init_arg)
    opts = [strategy: :one_for_one]

    _ = Logger.info("Starting #{__MODULE__}")
    Supervisor.init(args, opts)
  end

  defp children(args) do
    event_bus = Keyword.fetch!(args, :event_bus)
    num_blocks = Keyword.fetch!(args, :num_blocks)

    [
      {History, [event_bus: event_bus, num_blocks: num_blocks]},
      {BlockPercentileGasStrategy, []},
      {LegacyGasStrategy, []},
      {PoissonGasStrategy, []}
    ]
  end
end
