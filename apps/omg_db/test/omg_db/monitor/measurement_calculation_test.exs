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

defmodule OMG.DB.Monitor.MeasurementCalculationTest do
  use ExUnit.Case, async: true

  alias OMG.DB.Monitor.MeasurementCalculation
  alias OMG.Output
  alias OMG.TestHelper
  alias OMG.Utxo

  require Utxo

  @eth OMG.Eth.zero_address()
  @not_eth <<1::size(160)>>

  describe "balances_by_currency/1" do
    test "returns balances by currency" do
      alice = TestHelper.generate_entity()
      bob = TestHelper.generate_entity()
      carol = TestHelper.generate_entity()

      utxos = %{
        Utxo.position(2_000, 4076, 3) => %Utxo{
          output: %Output{amount: 700_000_000, currency: @eth, owner: alice}
        },
        Utxo.position(1_000, 2559, 0) => %Utxo{
          output: %Output{amount: 111_111_111, currency: @not_eth, owner: alice}
        },
        Utxo.position(8_000, 4854, 2) => %Utxo{
          output: %Output{amount: 77_000_000, currency: @eth, owner: bob}
        },
        Utxo.position(7_000, 4057, 3) => %Utxo{
          output: %Output{amount: 222_222_222, currency: @not_eth, owner: carol}
        },
        Utxo.position(7_000, 4057, 4) => %Utxo{output: %{}}
      }

      assert MeasurementCalculation.balances_by_currency(utxos) ==
               %{
                 @eth => 777_000_000,
                 @not_eth => 333_333_333
               }
    end
  end

  test "returns the total number of addresses with unspent outputs" do
    alice = TestHelper.generate_entity()
    bob = TestHelper.generate_entity()
    carol = TestHelper.generate_entity()

    utxos = %{
      Utxo.position(2_000, 4076, 3) => %Utxo{
        output: %Output{amount: 700_000_000, currency: @eth, owner: alice}
      },
      Utxo.position(1_000, 2559, 0) => %Utxo{
        output: %Output{amount: 111_111_111, currency: @not_eth, owner: alice}
      },
      Utxo.position(8_000, 4854, 2) => %Utxo{
        output: %Output{amount: 77_000_000, currency: @eth, owner: bob}
      },
      Utxo.position(7_000, 4057, 3) => %Utxo{
        output: %Output{amount: 222_222_222, currency: @not_eth, owner: carol}
      },
      Utxo.position(7_000, 4057, 4) => %Utxo{output: %{}}
    }

    assert MeasurementCalculation.total_unspent_addresses(utxos) == 3
  end

  test "returns the total number of unspent outputs" do
    alice = TestHelper.generate_entity()
    bob = TestHelper.generate_entity()
    carol = TestHelper.generate_entity()

    utxos = %{
      Utxo.position(2_000, 4076, 3) => %Utxo{
        output: %Output{amount: 700_000_000, currency: @eth, owner: alice}
      },
      Utxo.position(1_000, 2559, 0) => %Utxo{
        output: %Output{amount: 111_111_111, currency: @not_eth, owner: alice}
      },
      Utxo.position(8_000, 4854, 2) => %Utxo{
        output: %Output{amount: 77_000_000, currency: @eth, owner: bob}
      },
      Utxo.position(7_000, 4057, 3) => %Utxo{
        output: %Output{amount: 222_222_222, currency: @not_eth, owner: carol}
      },
      Utxo.position(7_000, 4057, 4) => %Utxo{output: %{}}
    }

    assert MeasurementCalculation.total_unspent_outputs(utxos) == 4
  end
end
