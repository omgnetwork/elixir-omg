# Copyright 2019-2019 OmiseGO Pte Ltd
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

defmodule OMG.ChildChain.ReleaseTasks.SetBlockSubmitGasPriceStrategy do
  @moduledoc false
  alias OMG.ChildChain.GasPrice.Strategy.LegacyGasStrategy
  alias OMG.ChildChain.GasPrice.Strategy.PoissonGasStrategy
  require Logger

  @behaviour Config.Provider

  @app :omg_child_chain
  @config_key :block_submit_gas_price_strategy
  @env_var_name "BLOCK_SUBMIT_GAS_PRICE_STRATEGY"

  def init(args) do
    args
  end

  def load(config, _args) do
    _ = on_load()
    strategy = strategy()
    Config.Reader.merge(config, omg_child_chain: [block_submit_gas_price_strategy: strategy])
  end

  defp strategy() do
    default = Application.get_env(@app, @config_key)

    strategy =
      @env_var_name
      |> System.get_env()
      |> get_strategy(default)

    _ = Logger.info("CONFIGURATION: App: #{@app} Key: #{@config_key} Value: #{inspect(strategy)}.")

    strategy
  end

  defp get_strategy("LEGACY", _), do: LegacyGasStrategy
  defp get_strategy("POISSON", _), do: PoissonGasStrategy
  defp get_strategy(nil, default), do: default
  defp get_strategy(input, _), do: exit("#{@env_var_name} must be either LEGACY or POISSON. Got #{inspect(input)}.")

  defp on_load() do
    _ = Application.ensure_all_started(:logger)
    _ = Application.load(@app)
  end
end
