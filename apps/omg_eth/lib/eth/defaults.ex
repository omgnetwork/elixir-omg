# Copyright 2018 OmiseGO Pte Ltd
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
  """

  import OMG.Eth.Encoding

  # safe, reasonable amount, equal to the testnet block gas limit
  @lots_of_gas 4_712_388
  @gas_price 20_000_000_000

  def tx_defaults do
    [value: 0, gasPrice: @gas_price, gas: @lots_of_gas]
    |> Enum.map(fn {k, v} -> {k, to_hex(v)} end)
  end
end
