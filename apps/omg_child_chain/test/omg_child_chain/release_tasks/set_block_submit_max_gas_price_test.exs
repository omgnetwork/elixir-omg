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

defmodule OMG.ChildChain.ReleaseTasks.SetBlockSubmitMaxGasPriceTest do
  use ExUnit.Case, async: true
  alias OMG.ChildChain.ReleaseTasks.SetBlockSubmitMaxGasPrice

  @app :omg_child_chain
  @config_key :block_submit_max_gas_price
  @env_var_name "BLOCK_SUBMIT_MAX_GAS_PRICE"

  test "sets the block_submit_max_gas_price when the system's env var is present" do
    :ok = System.put_env(@env_var_name, "1000000000")
    config = SetBlockSubmitMaxGasPrice.load([], [])
    configured_value = config |> Keyword.fetch!(@app) |> Keyword.fetch!(@config_key)
    assert configured_value == 1_000_000_000
    :ok = System.delete_env(@env_var_name)
  end

  test "uses the default app env value if not defined in system's env var" do
    :ok = System.delete_env(@env_var_name)
    default_value = Application.get_env(@app, @config_key)
    config = SetBlockSubmitMaxGasPrice.load([], [])
    configured_value = config |> Keyword.fetch!(@app) |> Keyword.fetch!(@config_key)
    assert configured_value == default_value
  end

  test "fails if the system's env value is not a valid stringified integer" do
    :ok = System.put_env(@env_var_name, "invalid")
    assert catch_error(SetBlockSubmitMaxGasPrice.load([], [])) == :badarg
    :ok = System.delete_env(@env_var_name)
  end
end
