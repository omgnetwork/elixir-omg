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
  @eth OMG.Eth.zero_address()
  @other_token <<127::160>>

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

      assert UtxoSelection.funds_sufficient(constructed_argument) ==
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

      %{@eth => [eth_utxo], @other_token => [other_token_utxo]} = DB.TxOutput.get_sorted_grouped_utxos(@alice)

      constructed_argument = [
        {@eth, {variances[@eth], [eth_utxo]}},
        {@other_token, {variances[@other_token], [other_token_utxo]}}
      ]

      assert {:ok,
              %{
                @eth => [eth_utxo],
                @other_token => [other_token_utxo]
              }} = UtxoSelection.funds_sufficient(constructed_argument)
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

      assert [{@eth, {-200, utxos}}] = UtxoSelection.select_utxo(needed_funds, utxos)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns the expected utxos if any of UTXOs exactly matched `needed_funds`" do
      needed_funds = %{
        @eth => 2_000
      }

      _ = insert(:txoutput, amount: 2_000, currency: @eth, owner: @alice)

      utxos = DB.TxOutput.get_sorted_grouped_utxos(@alice)

      assert [{@eth, {0, utxos}}] = UtxoSelection.select_utxo(needed_funds, utxos)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns positive variance if UTXOs don't cover `needed_funds`" do
      needed_funds = %{
        @eth => 2_000
      }

      _ = insert(:txoutput, amount: 500, currency: @eth, owner: @alice)
      _ = insert(:txoutput, amount: 500, currency: @eth, owner: @alice)

      utxos = DB.TxOutput.get_sorted_grouped_utxos(@alice)

      assert [{@eth, {1_000, _utxos}}] = UtxoSelection.select_utxo(needed_funds, utxos)
    end
  end

  describe "add_utxos_for_stealth_merge/2" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns selected UTXOs with no additions if the maximum has already been selected" do
      for _i <- 1..5 do
        _ = insert(:txoutput, owner: @alice)
      end

      [not_included | included] =
        @alice
        |> DB.TxOutput.get_sorted_grouped_utxos()
        |> Map.get(@eth)

      inputs = %{
        @eth => included
      }

      assert UtxoSelection.add_utxos_for_stealth_merge([not_included], inputs) == inputs
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns selected UTXOs with no additions if no other UTXOs are available" do
      for _i <- 1..4 do
        _ = insert(:txoutput, owner: @alice)
      end

      inputs = DB.TxOutput.get_sorted_grouped_utxos(@alice)
      other_available = []

      assert UtxoSelection.add_utxos_for_stealth_merge(other_available, inputs) == inputs
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "adds UTXOs until the limit is reached in the case of one currency" do
      for _i <- 1..5 do
        _ = insert(:txoutput, owner: @alice)
      end

      [included | available] =
        @alice
        |> DB.TxOutput.get_sorted_grouped_utxos()
        |> Map.get(@eth)

      [available_1, available_2, available_3 | _not_for_inclusion] = available

      inputs = %{
        @eth => [included]
      }

      expected = %{
        @eth => [available_3, available_2, available_1, included]
      }

      assert UtxoSelection.add_utxos_for_stealth_merge(available, inputs) == expected
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "adds UTXOs until the limit is reached in the case of multiple currencies" do
      _ = insert(:txoutput, currency: @eth, owner: @alice)
      _ = insert(:txoutput, currency: @eth, owner: @alice)
      _ = insert(:txoutput, currency: @other_token, owner: @alice)
      _ = insert(:txoutput, currency: @other_token, owner: @alice)

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
             } = UtxoSelection.add_utxos_for_stealth_merge([merge_1, merge_2], inputs)
    end
  end

  describe "prioritize_merge_utxos/2" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns only UTXOs that have not already been selected for the transaction" do
      _ = insert(:txoutput, currency: @eth, owner: @alice)
      _ = insert(:txoutput, currency: @eth, owner: @alice)
      _ = insert(:txoutput, currency: @eth, owner: @alice)
      _ = insert(:txoutput, currency: @eth, owner: @alice)

      %{
        @eth => [selected_eth | available_eth]
      } = utxos = DB.TxOutput.get_sorted_grouped_utxos(@alice)

      inputs = %{
        @eth => [selected_eth]
      }

      result = UtxoSelection.prioritize_merge_utxos(utxos, inputs)

      assert result == available_eth
      assert Enum.member?(result, selected_eth) == false
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns UTXOs only for currencies already in the transaction" do
      token_a = <<65::160>>
      token_b = <<66::160>>
      token_c = <<67::160>>

      _ = insert(:txoutput, currency: token_a, owner: @alice)
      _ = insert(:txoutput, currency: token_a, owner: @alice)
      _ = insert(:txoutput, currency: token_b, owner: @alice)
      _ = insert(:txoutput, currency: token_b, owner: @alice)
      _ = insert(:txoutput, currency: token_c, owner: @alice)
      _ = insert(:txoutput, currency: token_c, owner: @alice)

      %{
        ^token_a => [utxo_a_1, utxo_a_2],
        ^token_b => [utxo_b_1, utxo_b_2],
        ^token_c => [_, _]
      } = utxos = DB.TxOutput.get_sorted_grouped_utxos(@alice)

      inputs = %{
        token_a => [utxo_a_1],
        token_b => [utxo_b_1]
      }

      result = UtxoSelection.prioritize_merge_utxos(utxos, inputs)

      assert result == [utxo_a_2, utxo_b_2]
      assert Enum.find(result, fn utxo -> utxo.currency == token_c end) == nil
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "orders UTXOs by currency in descending order of set size" do
      token_a = <<65::160>>
      token_b = <<66::160>>
      token_c = <<67::160>>

      for _i <- 1..4 do
        _ = insert(:txoutput, currency: token_a, owner: @alice)
      end

      for _i <- 1..3 do
        _ = insert(:txoutput, currency: token_b, owner: @alice)
      end

      for _i <- 1..2 do
        _ = insert(:txoutput, currency: token_c, owner: @alice)
      end

      %{
        ^token_a => [selected_a | available_a],
        ^token_b => [selected_b | available_b],
        ^token_c => [selected_c | available_c]
      } = utxos = DB.TxOutput.get_sorted_grouped_utxos(@alice)

      inputs = %{
        token_a => [selected_a],
        token_b => [selected_b],
        token_c => [selected_c]
      }

      result = UtxoSelection.prioritize_merge_utxos(utxos, inputs)

      assert result == available_a ++ available_b ++ available_c
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "orders UTXOs by currency in descending order of set size, excluding already selected UTXOs" do
      token_a = <<65::160>>
      token_b = <<66::160>>

      for _i <- 1..3 do
        _ = insert(:txoutput, currency: token_a, owner: @alice)
        _ = insert(:txoutput, currency: token_b, owner: @alice)
      end

      %{
        ^token_a => [a_1, a_2, a_3],
        ^token_b => [b_1, b_2, b_3]
      } = utxos = DB.TxOutput.get_sorted_grouped_utxos(@alice)

      inputs = %{
        token_a => [a_1, a_2],
        token_b => [b_1]
      }

      assert UtxoSelection.prioritize_merge_utxos(utxos, inputs) == [b_2, b_3, a_3]
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "within the currency grouping, orders UTXOs in ascending order of value ('dust first')" do
      token_a = <<65::160>>
      token_b = <<66::160>>

      _ = insert(:txoutput, amount: 10, currency: token_a, owner: @alice)
      _ = insert(:txoutput, amount: 30, currency: token_b, owner: @alice)
      _ = insert(:txoutput, amount: 20, currency: token_a, owner: @alice)
      _ = insert(:txoutput, amount: 40, currency: token_b, owner: @alice)
      _ = insert(:txoutput, amount: 40, currency: token_a, owner: @alice)
      _ = insert(:txoutput, amount: 20, currency: token_b, owner: @alice)
      _ = insert(:txoutput, amount: 30, currency: token_a, owner: @alice)
      _ = insert(:txoutput, amount: 10, currency: token_b, owner: @alice)

      %{
        ^token_a => [a_1 | available_a],
        ^token_b => [b_1, b_2 | available_b]
      } = utxos = DB.TxOutput.get_sorted_grouped_utxos(@alice)

      inputs = %{
        token_a => [a_1],
        token_b => [b_1, b_2]
      }

      sorted_available_a = Enum.sort_by(available_a, fn utxo -> utxo.amount end, :asc)
      sorted_available_b = Enum.sort_by(available_b, fn utxo -> utxo.amount end, :asc)

      assert UtxoSelection.prioritize_merge_utxos(utxos, inputs) == Enum.concat(sorted_available_a, sorted_available_b)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns no more than 3 UTXOs per currency grouping" do
      for _i <- 1..5 do
        _ = insert(:txoutput, currency: @eth, owner: @alice)
      end

      %{
        @eth => [eth_1 | available_eth]
      } = utxos = DB.TxOutput.get_sorted_grouped_utxos(@alice)

      assert length(available_eth) > 3

      inputs = %{
        @eth => [eth_1]
      }

      assert UtxoSelection.prioritize_merge_utxos(utxos, inputs)
             |> Enum.filter(fn utxo -> utxo.currency == @eth end)
             |> length() == 3
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns empty list when original utxos are empty" do
      _ = insert(:txoutput, currency: @eth, owner: @alice)
      _ = insert(:txoutput, currency: @eth, owner: @alice)

      utxos = DB.TxOutput.get_sorted_grouped_utxos(@alice)

      assert [] == UtxoSelection.prioritize_merge_utxos(utxos, %{})
    end
  end
end
