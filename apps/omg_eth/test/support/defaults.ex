# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.Eth.Defaults do
  @moduledoc """
  Internal defaults of non-production critical calls to `OMG.Eth.RootChain` and `OMG.Eth.Token`.

  Don't ever use this for `OMG.Eth.RootChain.submit_block/5` or any other production related code.
  Don't ever use this for `OMG.Eth.submit_block/5` or any other production related code.
  """

  alias OMG.Eth.Encoding

  # safe, reasonable amount, equal to the testnet block gas limit
  @lots_of_gas 5_712_388
  @gas_price 1_000_000_000

  def tx_defaults() do
    Enum.map([value: 0, gasPrice: @gas_price, gas: @lots_of_gas], fn {k, v} -> {k, Encoding.to_hex(v)} end)
  end
end
