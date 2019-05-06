# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.State.Core.MetricsTest do
  @moduledoc """
  Tests functional behaviors of `OMG.State.Core.Metrics`.
  """
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.Eth.Encoding
  alias OMG.State.Core
  alias OMG.Utxo

  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @not_eth <<1::size(160)>>
  @tag fixtures: [:alice, :bob, :carol]

  test "calculate metrics from state", %{alice: alice, bob: bob, carol: carol} do
    utxos = %{
      Utxo.position(2_835, 4076, 3) => %OMG.Utxo{amount: 700_000_000, currency: @eth, owner: alice},
      Utxo.position(1_075, 2559, 0) => %OMG.Utxo{amount: 111_111_111, currency: @not_eth, owner: alice},
      Utxo.position(8_149, 4854, 2) => %OMG.Utxo{amount: 77_000_000, currency: @eth, owner: bob},
      Utxo.position(7_202, 4057, 3) => %OMG.Utxo{amount: 222_222_222, currency: @not_eth, owner: carol}
    }

    assert MapSet.new(Core.Metrics.calculate(%Core{utxos: utxos})) ==
             MapSet.new([
               {"unique_users", 3},
               {"balance_" <> Encoding.to_hex(@eth), 777_000_000},
               {"balance_" <> Encoding.to_hex(@not_eth), 333_333_333}
             ])
  end
end
