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

  describe "merge/1" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "merge with address and currency does so correctly" do
      insert_initial_utxo()

      _ = :txoutput |> insert(currency: @currency_1, owner: @alice, amount: 1)
      _ = :txoutput |> insert(currency: @currency_1, owner: @alice, amount: 1)
      _ = :txoutput |> insert(currency: @currency_1, owner: @alice, amount: 1)

      merge_tx = Transaction.merge(%{address: @alice, currency: @currency_1})
      assert length(merge_tx) == 1

      %{outputs: outputs} = List.first(merge_tx)
      assert outputs === [%{amount: 3, currency: @currency_1, owner: @alice}]
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "given `utxo_positions` parameter, returns an error if any position is not found" do
      insert_initial_utxo()

      position_1 = :txoutput |> insert() |> encoded_position_from_insert()
      position_2 = :txoutput |> insert() |> encoded_position_from_insert()
      position_3 = :txoutput |> insert() |> encoded_position_from_insert()

      empty_position = insert(:txoutput) |> Map.update!(:blknum, fn n -> n + 1 end) |> encoded_position_from_insert()

      assert Transaction.merge(%{utxo_positions: [position_1, position_2, position_3, empty_position]}) ==
               {:error, :input_not_found}
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "given `utxo_positions` parameter, returns an error if the corresponding UTXOs belong to more than one address" do
      insert_initial_utxo()

      position_1 = :txoutput |> insert(owner: @alice) |> encoded_position_from_insert()
      position_2 = :txoutput |> insert(owner: @alice) |> encoded_position_from_insert()
      position_3 = :txoutput |> insert(owner: @bob) |> encoded_position_from_insert()

      assert Transaction.merge(%{utxo_positions: [position_1, position_2, position_3]}) ==
               {:error, :multiple_input_owners}
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "given `utxo_positions` parameter, returns an error if a currency has less than two UTXOs" do
      insert_initial_utxo()

      position_1 = :txoutput |> insert(owner: @alice, currency: @currency_1) |> encoded_position_from_insert()
      position_2 = :txoutput |> insert(owner: @alice, currency: @currency_1) |> encoded_position_from_insert()
      position_3 = :txoutput |> insert(owner: @alice, currency: @currency_2) |> encoded_position_from_insert()

      assert Transaction.merge(%{utxo_positions: [position_1, position_2, position_3]}) ==
               {:error, :single_input_for_ccy}
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
