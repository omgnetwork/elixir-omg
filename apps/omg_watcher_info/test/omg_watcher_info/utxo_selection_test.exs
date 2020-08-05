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

defmodule OMG.WatcherInfo.UtxoSelectionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures

  alias OMG.Utxo
  alias OMG.WatcherInfo.DB
  alias OMG.WatcherInfo.UtxoSelection

  import OMG.WatcherInfo.Factory

  require Utxo

  @eth OMG.Eth.zero_address()
  @other_token <<127::160>>

  describe "create_advice/2" do
    @tag fixtures: [:phoenix_ecto_sandbox, :alice, :bob]
    test "returns {:ok, %{result: :complete}}", %{alice: alice, bob: bob} do
      amount_1 = 1000
      amount_2 = 2000

      _ = insert(:txoutput, amount: amount_1, currency: @eth, owner: alice.addr)
      _ = insert(:txoutput, amount: amount_2, currency: @eth, owner: alice.addr)

      utxos = DB.TxOutput.get_sorted_grouped_utxos(alice.addr)

      order = %{
        owner: bob.addr,
        payments: [
          %{
            owner: alice.addr,
            currency: @eth,
            amount: 1000
          }
        ],
        fee: %{
          currency: @eth,
          amount: 1000
        },
        metadata: nil
      }

      assert {:ok, %{result: :complete}} = UtxoSelection.create_advice(utxos, order)
    end
  end

  describe "needed_funds/2" do
    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "returns a correct map when payment_currency != fee_currency", %{alice: alice} do
      payment_currency = @eth
      fee_currency = @other_token

      payments = [
        %{
          owner: alice.addr,
          currency: payment_currency,
          amount: 1_000
        }
      ]

      fee = %{
        currency: fee_currency,
        amount: 2_000
      }

      assert %{
               payment_currency => 1_000,
               fee_currency => 2_000
             } == UtxoSelection.needed_funds(payments, fee)
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "returns a correct map when payment_currency == fee_currency", %{alice: alice} do
      payment_currency = @eth

      payments = [
        %{
          owner: alice.addr,
          currency: payment_currency,
          amount: 1_000
        }
      ]

      fee = %{
        currency: payment_currency,
        amount: 2_000
      }

      assert %{
               payment_currency => 3_000
             } == UtxoSelection.needed_funds(payments, fee)
    end
  end
end
