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

defmodule OMG.State.MeasurementCalculationTest do
  @moduledoc """
  Testing functional behaviors.
  """
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.Eth.Encoding
  alias OMG.State.Core

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @not_eth <<1::size(160)>>
  @tag fixtures: [:alice, :bob, :carol]

  test "calculate metrics from state", %{alice: alice, bob: bob, carol: carol} do
    utxos = %{
      %OMG.InputPointer{blknum: 2_000, txindex: 4076, oindex: 3} => %OMG.Utxo{
        output: %OMG.Output.FungibleMoreVPToken{amount: 700_000_000, currency: @eth, owner: alice}
      },
      %OMG.InputPointer{blknum: 1_000, txindex: 2559, oindex: 0} => %OMG.Utxo{
        output: %OMG.Output.FungibleMoreVPToken{amount: 111_111_111, currency: @not_eth, owner: alice}
      },
      %OMG.InputPointer{blknum: 8_000, txindex: 4854, oindex: 2} => %OMG.Utxo{
        output: %OMG.Output.FungibleMoreVPToken{amount: 77_000_000, currency: @eth, owner: bob}
      },
      %OMG.InputPointer{blknum: 7_000, txindex: 4057, oindex: 3} => %OMG.Utxo{
        output: %OMG.Output.FungibleMoreVPToken{amount: 222_222_222, currency: @not_eth, owner: carol}
      },
      %OMG.InputPointer{blknum: 7_000, txindex: 4057, oindex: 4} => %OMG.Utxo{output: %{}}
    }

    assert MapSet.new(OMG.State.MeasurementCalculation.calculate(%Core{utxos: utxos})) ==
             MapSet.new([
               {:unique_users, 3},
               {:balance, 777_000_000, "currency:#{Encoding.to_hex(@eth)}"},
               {:balance, 333_333_333, "currency:#{Encoding.to_hex(@not_eth)}"}
             ])
  end
end
