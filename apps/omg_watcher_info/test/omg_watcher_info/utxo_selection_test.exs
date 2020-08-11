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

  describe "select_utxo/2" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns the expected utxos if UTXOs cover `needed_funds" do
      needed_funds = %{
        @eth => 2_000
      }

      _ = insert(:txoutput, amount: 1_200, currency: @eth, owner: @alice)
      _ = insert(:txoutput, amount: 1_000, currency: @eth, owner: @alice)

      utxos = DB.TxOutput.get_sorted_grouped_utxos(@alice)

      assert [{@eth, {-200, utxos}}] = UtxoSelection.select_utxo(utxos, needed_funds)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns the expected utxos if any of UTXOs exactly matched `needed_funds`" do
      needed_funds = %{
        @eth => 2_000
      }

      _ = insert(:txoutput, amount: 2_000, currency: @eth, owner: @alice)

      utxos = DB.TxOutput.get_sorted_grouped_utxos(@alice)

      assert [{@eth, {0, utxos}}] = UtxoSelection.select_utxo(utxos, needed_funds)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns positive variance if UTXOs don't cover `needed_funds`" do
      needed_funds = %{
        @eth => 2_000
      }

      _ = insert(:txoutput, amount: 500, currency: @eth, owner: @alice)
      _ = insert(:txoutput, amount: 500, currency: @eth, owner: @alice)

      utxos = DB.TxOutput.get_sorted_grouped_utxos(@alice)

      assert [{@eth, {1_000, _utxos}}] = UtxoSelection.select_utxo(utxos, needed_funds)
    end
  end

  describe "add_merge_utxos/2" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns expected utxos when have 2 eth, 2 other and there're 1 eth and 1 other in the inputs" do
      _ = insert(:txoutput, amount: 100, currency: @eth, owner: @alice)
      _ = insert(:txoutput, amount: 200, currency: @eth, owner: @alice)
      _ = insert(:txoutput, amount: 100, currency: @other_token, owner: @alice)
      _ = insert(:txoutput, amount: 200, currency: @other_token, owner: @alice)

      utxos = DB.TxOutput.get_sorted_grouped_utxos(@alice)
      [input_1, merge_1] = Map.get(utxos, @eth)
      [input_2, merge_2] = Map.get(utxos, @other_token)

      inputs = %{
        @eth => [input_1],
        @other_token => [input_2]
      }

      assert %{
               @eth => [input_1, merge_1],
               @other_token => [input_2, merge_2]
             } = UtxoSelection.add_merge_utxos(inputs, [merge_1, merge_2])
    end
  end

  describe "prioritize_merge_utxos" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns the same currencies as inputs but excluding utxos used by inputs" do
      token_a = <<65::160>>
      token_b = <<66::160>>
      token_c = <<67::160>>

      _ = insert(:txoutput, amount: 100, currency: token_a, owner: @alice)
      _ = insert(:txoutput, amount: 200, currency: token_a, owner: @alice)
      _ = insert(:txoutput, amount: 100, currency: token_b, owner: @alice)
      _ = insert(:txoutput, amount: 200, currency: token_b, owner: @alice)
      _ = insert(:txoutput, amount: 100, currency: token_c, owner: @alice)
      _ = insert(:txoutput, amount: 200, currency: token_c, owner: @alice)

      utxos = DB.TxOutput.get_sorted_grouped_utxos(@alice)

      [utxo_a_1, utxo_a_2] = utxos[token_a]
      [utxo_b_1, utxo_b_2] = utxos[token_b]

      inputs = %{
        token_a => [utxo_a_1],
        token_b => [utxo_b_1],
      }

      assert [utxo_a_2, utxo_b_2] == UtxoSelection.prioritize_merge_utxos(inputs, utxos)
    end
  end
end
