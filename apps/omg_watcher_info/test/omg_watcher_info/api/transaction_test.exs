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

defmodule OMG.WatcherInfo.API.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.WatcherInfo.Fixtures

  alias OMG.Utxo.Position
  alias OMG.WatcherInfo.API.Transaction

  import OMG.WatcherInfo.Factory

  @alice <<1::160>>
  @bob <<2::160>>
  @currency_1 <<3::160>>
  @currency_2 <<4::160>>

  describe "merge/1 with address and currency parameters" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "merge with address and currency forms multiple merge transactions if possible" do
      insert_initial_utxo()

      _ = insert(:txoutput, currency: @currency_1, owner: @alice, amount: 1)
      _ = insert(:txoutput, currency: @currency_1, owner: @alice, amount: 1)
      _ = insert(:txoutput, currency: @currency_1, owner: @alice, amount: 1)
      _ = insert(:txoutput, currency: @currency_1, owner: @alice, amount: 1)
      _ = insert(:txoutput, currency: @currency_1, owner: @alice, amount: 1)
      _ = insert(:txoutput, currency: @currency_1, owner: @alice, amount: 1)
      _ = insert(:txoutput, currency: @currency_1, owner: @alice, amount: 1)

      assert {:ok, [%{inputs: [_, _, _, _], outputs: [output_1]}, %{inputs: [_, _, _], outputs: [output_2]}]} =
               Transaction.merge(%{address: @alice, currency: @currency_1})

      assert output_1 === %{amount: 4, currency: @currency_1, owner: @alice}
      assert output_2 === %{amount: 3, currency: @currency_1, owner: @alice}
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "fetches inputs for the given addresss only" do
      insert_initial_utxo()

      _ = insert(:txoutput, currency: @currency_1, owner: @bob, amount: 1)
      _ = insert(:txoutput, currency: @currency_1, owner: @bob, amount: 1)
      _ = insert(:txoutput, currency: @currency_1, owner: @alice, amount: 1)
      _ = insert(:txoutput, currency: @currency_1, owner: @alice, amount: 1)
      _ = insert(:txoutput, currency: @currency_1, owner: @alice, amount: 1)
      _ = insert(:txoutput, currency: @currency_1, owner: @alice, amount: 1)

      assert {:ok, [alice_merge]} = Transaction.merge(%{address: @alice, currency: @currency_1})
      assert %{inputs: [_, _, _, _], outputs: [%{amount: 4, currency: @currency_1, owner: @alice}]} = alice_merge
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "fetches inputs for the given currency only" do
      insert_initial_utxo()

      _ = insert(:txoutput, currency: @currency_1, owner: @alice, amount: 1)
      _ = insert(:txoutput, currency: @currency_1, owner: @alice, amount: 1)
      _ = insert(:txoutput, currency: @currency_2, owner: @alice, amount: 1)
      _ = insert(:txoutput, currency: @currency_2, owner: @alice, amount: 1)

      assert {:ok, [alice_merge]} = Transaction.merge(%{address: @alice, currency: @currency_2})
      assert %{inputs: [_, _], outputs: [%{amount: 2, currency: @currency_2, owner: @alice}]} = alice_merge
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns one merge transaction if five UTXOs are available – prioritising the lowest value inputs" do
      insert_initial_utxo()

      _ = insert(:txoutput, currency: @currency_1, owner: @alice, amount: 1)
      _ = insert(:txoutput, currency: @currency_1, owner: @alice, amount: 2)
      _ = insert(:txoutput, currency: @currency_1, owner: @alice, amount: 3)
      _ = insert(:txoutput, currency: @currency_1, owner: @alice, amount: 4)
      _ = insert(:txoutput, currency: @currency_1, owner: @alice, amount: 5)

      assert {:ok, [merge_tx]} = Transaction.merge(%{address: @alice, currency: @currency_1})

      assert %{
               inputs: [%{amount: 1}, %{amount: 2}, %{amount: 3}, %{amount: 4}],
               outputs: [%{amount: 10, currency: @currency_1, owner: @alice}]
             } = merge_tx
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "merge with address and currency fails on single input" do
      insert_initial_utxo()

      _ = insert(:txoutput, currency: @currency_1, owner: @alice, amount: 1)
      _ = insert(:txoutput, currency: @currency_2, owner: @alice, amount: 1)

      assert Transaction.merge(%{address: @alice, currency: @currency_1}) ==
               {:error, :no_possible_merge_combination}
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns expected error when no inputs are found" do
      assert Transaction.merge(%{address: @alice, currency: @currency_1}) == {:error, :no_inputs_found}
    end
  end

  describe "merge/1 with utxo_positions parameter" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "given `utxo_positions` parameter, forms multiple merge transactions correctly if more than four positions given" do
      insert_initial_utxo()

      position_1 =
        :txoutput |> insert(owner: @alice, currency: @currency_1, amount: 1) |> encoded_position_from_insert()

      position_2 =
        :txoutput |> insert(owner: @alice, currency: @currency_1, amount: 1) |> encoded_position_from_insert()

      position_3 =
        :txoutput |> insert(owner: @alice, currency: @currency_1, amount: 1) |> encoded_position_from_insert()

      position_4 =
        :txoutput |> insert(owner: @alice, currency: @currency_1, amount: 1) |> encoded_position_from_insert()

      position_5 =
        :txoutput |> insert(owner: @alice, currency: @currency_1, amount: 1) |> encoded_position_from_insert()

      position_6 =
        :txoutput |> insert(owner: @alice, currency: @currency_1, amount: 1) |> encoded_position_from_insert()

      position_7 =
        :txoutput |> insert(owner: @alice, currency: @currency_1, amount: 1) |> encoded_position_from_insert()

      {:ok, merge_txs} =
        Transaction.merge(%{
          utxo_positions: [position_1, position_2, position_3, position_4, position_5, position_6, position_7]
        })

      [%{inputs: inputs_1, outputs: [output_1]}, %{inputs: inputs_2, outputs: [output_2]}] = merge_txs

      assert length(inputs_1) == 4
      assert length(inputs_2) == 3
      assert output_1 === %{amount: 4, currency: @currency_1, owner: @alice}
      assert output_2 === %{amount: 3, currency: @currency_1, owner: @alice}
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "given `utxo_positions` parameters, forms a merge transaction correctly" do
      insert_initial_utxo()

      position_1 =
        :txoutput |> insert(owner: @alice, currency: @currency_1, amount: 1) |> encoded_position_from_insert()

      position_2 =
        :txoutput |> insert(owner: @alice, currency: @currency_1, amount: 1) |> encoded_position_from_insert()

      position_3 =
        :txoutput |> insert(owner: @alice, currency: @currency_1, amount: 1) |> encoded_position_from_insert()

      {:ok, [%{inputs: inputs, outputs: outputs}]} =
        Transaction.merge(%{utxo_positions: [position_1, position_2, position_3]})

      assert length(inputs) == 3
      assert [%{amount: 3, currency: @currency_1, owner: @alice}] = outputs
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns an error if any duplicate positions are in the list" do
      insert_initial_utxo()

      position_1 = :txoutput |> insert() |> encoded_position_from_insert()

      assert Transaction.merge(%{utxo_positions: [position_1, position_1]}) ==
               {:error, :duplicate_input_positions}
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns expected error if any position is not found" do
      insert_initial_utxo()

      position_1 = :txoutput |> insert() |> encoded_position_from_insert()
      position_2 = :txoutput |> insert() |> encoded_position_from_insert()
      position_3 = :txoutput |> insert() |> encoded_position_from_insert()

      empty_position = insert(:txoutput) |> Map.update!(:blknum, fn n -> n + 1 end) |> encoded_position_from_insert()

      assert Transaction.merge(%{utxo_positions: [position_1, position_2, position_3, empty_position]}) ==
               {:error, :position_not_found}
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "accepts multiple owners if they are segmented by currency" do
      insert_initial_utxo()

      position_1 = :txoutput |> insert(owner: @alice, currency: @currency_1) |> encoded_position_from_insert()
      position_2 = :txoutput |> insert(owner: @alice, currency: @currency_1) |> encoded_position_from_insert()
      position_3 = :txoutput |> insert(owner: @bob, currency: @currency_2) |> encoded_position_from_insert()
      position_4 = :txoutput |> insert(owner: @bob, currency: @currency_2) |> encoded_position_from_insert()

      {:ok, [merge_1, merge_2]} = Transaction.merge(%{utxo_positions: [position_1, position_2, position_3, position_4]})

      assert [%{currency: @currency_2, owner: @bob}, %{currency: @currency_2, owner: @bob}] = merge_1.inputs
      assert [%{currency: @currency_1, owner: @alice}, %{currency: @currency_1, owner: @alice}] = merge_2.inputs
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns an error if there is more than one owner for a currency" do
      insert_initial_utxo()

      position_1 = :txoutput |> insert(owner: @alice, currency: @currency_1) |> encoded_position_from_insert()
      position_2 = :txoutput |> insert(owner: @alice, currency: @currency_1) |> encoded_position_from_insert()
      position_3 = :txoutput |> insert(owner: @bob, currency: @currency_1) |> encoded_position_from_insert()

      assert Transaction.merge(%{utxo_positions: [position_1, position_2, position_3]}) ==
               {:error, :multiple_input_owners}
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns transaction by currency when given positions corresponding to multiple currencies (unordered)" do
      insert_initial_utxo()

      position_1 = :txoutput |> insert(owner: @alice, currency: @currency_1) |> encoded_position_from_insert()
      position_2 = :txoutput |> insert(owner: @alice, currency: @currency_1) |> encoded_position_from_insert()
      position_3 = :txoutput |> insert(owner: @alice, currency: @currency_1) |> encoded_position_from_insert()
      position_4 = :txoutput |> insert(owner: @alice, currency: @currency_2) |> encoded_position_from_insert()
      position_5 = :txoutput |> insert(owner: @alice, currency: @currency_1) |> encoded_position_from_insert()
      position_6 = :txoutput |> insert(owner: @alice, currency: @currency_1) |> encoded_position_from_insert()
      position_7 = :txoutput |> insert(owner: @alice, currency: @currency_1) |> encoded_position_from_insert()
      position_8 = :txoutput |> insert(owner: @alice, currency: @currency_2) |> encoded_position_from_insert()

      {:ok, [merge_1, merge_2, merge_3]} =
        Transaction.merge(%{
          utxo_positions: [
            position_1,
            position_2,
            position_3,
            position_4,
            position_5,
            position_6,
            position_7,
            position_8
          ]
        })

      assert [%{currency: @currency_2}, %{currency: @currency_2}] = Map.get(merge_1, :inputs)

      assert [%{currency: @currency_1}, %{currency: @currency_1}, %{currency: @currency_1}, %{currency: @currency_1}] =
               Map.get(merge_2, :inputs)

      assert [%{currency: @currency_1}, %{currency: @currency_1}] = Map.get(merge_3, :inputs)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "drops currencies for which only one position is given while forming transactions for others where two or more are given" do
      insert_initial_utxo()

      position_1 = :txoutput |> insert(owner: @alice, currency: @currency_1) |> encoded_position_from_insert()
      position_2 = :txoutput |> insert(owner: @alice, currency: @currency_1) |> encoded_position_from_insert()
      position_3 = :txoutput |> insert(owner: @alice, currency: @currency_2) |> encoded_position_from_insert()

      assert {:ok, [merge_transaction]} = Transaction.merge(%{utxo_positions: [position_1, position_2, position_3]})
      assert [%{currency: @currency_1}, %{currency: @currency_1}] = Map.get(merge_transaction, :inputs)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns expected error if only single outputs per currency are given" do
      insert_initial_utxo()

      position_1 = :txoutput |> insert(owner: @alice, currency: @currency_1) |> encoded_position_from_insert()
      position_2 = :txoutput |> insert(owner: @alice, currency: @currency_2) |> encoded_position_from_insert()

      assert Transaction.merge(%{utxo_positions: [position_1, position_2]}) == {:error, :no_possible_merge_combination}
    end
  end

  defp encoded_position_from_insert(%{oindex: oindex, txindex: txindex, blknum: blknum}) do
    Position.encode({:utxo_position, blknum, txindex, oindex})
  end

  # This is needed so that UTXOs inserted subsequently can have a proper (non-zero) position
  defp insert_initial_utxo() do
    insert(:txoutput)
  end
end
