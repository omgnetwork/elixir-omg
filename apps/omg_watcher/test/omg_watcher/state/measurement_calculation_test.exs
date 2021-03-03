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

defmodule OMG.Watcher.State.MeasurementCalculationTest do
  @moduledoc """
  Testing functional behaviors.
  """
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.Eth.Encoding
  alias OMG.Watcher.State.Core
  alias OMG.Watcher.Utxo

  require Utxo

  @eth <<0::160>>
  @not_eth <<1::size(160)>>
  @tag fixtures: [:alice, :bob, :carol]

  test "calculate metrics from state", %{alice: alice, bob: bob, carol: carol} do
    utxos = %{
      Utxo.position(2_000, 4076, 3) => %OMG.Watcher.Utxo{
        output: %OMG.Watcher.Output{amount: 700_000_000, currency: @eth, owner: alice}
      },
      Utxo.position(1_000, 2559, 0) => %OMG.Watcher.Utxo{
        output: %OMG.Watcher.Output{amount: 111_111_111, currency: @not_eth, owner: alice}
      },
      Utxo.position(8_000, 4854, 2) => %OMG.Watcher.Utxo{
        output: %OMG.Watcher.Output{amount: 77_000_000, currency: @eth, owner: bob}
      },
      Utxo.position(7_000, 4057, 3) => %OMG.Watcher.Utxo{
        output: %OMG.Watcher.Output{amount: 222_222_222, currency: @not_eth, owner: carol}
      },
      Utxo.position(7_000, 4057, 4) => %OMG.Watcher.Utxo{output: %{}}
    }

    assert MapSet.new(OMG.Watcher.State.MeasurementCalculation.calculate(%Core{utxos: utxos})) ==
             MapSet.new([
               {:unique_users, 3},
               {:balance, 777_000_000, "currency:#{Encoding.to_hex(@eth)}"},
               {:balance, 333_333_333, "currency:#{Encoding.to_hex(@not_eth)}"}
             ])
  end
end
