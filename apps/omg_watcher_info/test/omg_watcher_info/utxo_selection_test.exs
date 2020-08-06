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

  alias OMG.Eth.Encoding
  alias OMG.Utxo
  alias OMG.WatcherInfo.DB
  alias OMG.WatcherInfo.UtxoSelection

  import OMG.WatcherInfo.Factory

  require Utxo

  @alice <<27::160>>
  @bob <<28::160>>
  @eth OMG.Eth.zero_address()
  @other_token <<127::160>>

  describe "create_advice/2" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns {:ok, %{result: :complete}}" do
      amount_1 = 1000
      amount_2 = 2000

      _ = insert(:txoutput, amount: amount_1, currency: @eth, owner: @alice)
      _ = insert(:txoutput, amount: amount_2, currency: @eth, owner: @alice)

      utxos = DB.TxOutput.get_sorted_grouped_utxos(@alice)

      order = %{
        owner: @bob,
        payments: [
          %{
            owner: @alice,
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
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns a correct map when payment_currency != fee_currency" do
      payment_currency = @eth
      fee_currency = @other_token

      payments = [
        %{
          owner: @alice,
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

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns a correct map when payment_currency == fee_currency" do
      payment_currency = @eth

      payments = [
        %{
          owner: @alice,
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

  describe "funds_sufficient/1" do
    test "should return the expected error if UTXOs do not cover the amount of the transaction order" do
      variances = %{@eth => 5, @other_token => 10}

      # UTXO list is empty for simplicty as the error response does not need it.
      utxo_list = []

      constructed_argument = Enum.map([@eth, @other_token], fn ccy -> {ccy, {variances[ccy], utxo_list}} end)

      assert UtxoSelection.funds_sufficient?(constructed_argument) ==
               {:error,
                {:insufficient_funds,
                 [
                   %{missing: variances[@eth], token: Encoding.to_hex(@eth)},
                   %{missing: variances[@other_token], token: Encoding.to_hex(@other_token)}
                 ]}}
    end
  end

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "should return the expected response if UTXOs cover the amount of the transaction order" do
    variances = %{@eth => -5, @other_token => 0}

    _ = insert(:txoutput, amount: 100, currency: @eth, owner: @alice)
    _ = insert(:txoutput, amount: 100, currency: @other_token, owner: @alice)

    utxos = DB.TxOutput.get_sorted_grouped_utxos(@alice)

    constructed_argument = Enum.map([@eth, @other_token], fn ccy -> {ccy, {variances[ccy], utxos[ccy]}} end)

    assert {:ok,
            [
              {@eth, [%DB.TxOutput{currency: @eth}]},
              {@other_token, [%DB.TxOutput{currency: @other_token}]}
            ]} = UtxoSelection.funds_sufficient?(constructed_argument)
  end
end
