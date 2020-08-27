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

defmodule OMG.WatcherRPC.Web.View.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.WatcherInfo.Fixtures

  alias OMG.Utils.Paginator
  alias OMG.Utxo
  alias OMG.WatcherInfo.DB
  alias OMG.WatcherInfo.API.Transaction
  alias OMG.WatcherRPC.Web.View

  import OMG.WatcherInfo.Factory

  require Utxo

  @alice <<1::160>>
  @currency <<2::160>>

  describe "render/2 with transaction.json" do
    @tag fixtures: [:initial_blocks]
    test "renders the transaction's inputs and outputs" do
      transaction =
        1000
        |> DB.Transaction.get_by_position(1)
        |> DB.Repo.preload([:inputs, :outputs])

      rendered = View.Transaction.render("transaction.json", %{response: transaction})

      # Asserts all transaction inputs get rendered
      assert Map.has_key?(rendered.data, :inputs)
      assert utxos_match_all?(rendered.data.inputs, transaction.inputs)

      # Asserts all transaction outputs get rendered
      assert Map.has_key?(rendered.data, :outputs)
      assert utxos_match_all?(rendered.data.outputs, transaction.outputs)
    end
  end

  describe "render/2 with transactions.json" do
    @tag fixtures: [:initial_blocks]
    test "renders the transactions' inputs and outputs" do
      tx_1 = DB.Transaction.get_by_position(1000, 0) |> DB.Repo.preload([:inputs, :outputs])
      tx_2 = DB.Transaction.get_by_position(1000, 1) |> DB.Repo.preload([:inputs, :outputs])

      paginator = %Paginator{
        data: [tx_1, tx_2],
        data_paging: %{
          limit: 10,
          page: 1
        }
      }

      rendered = View.Transaction.render("transactions.json", %{response: paginator})
      [rendered_1, rendered_2] = rendered.data

      assert utxos_match_all?(rendered_1.inputs, tx_1.inputs)
      assert utxos_match_all?(rendered_1.outputs, tx_1.outputs)
      assert utxos_match_all?(rendered_2.inputs, tx_2.inputs)
      assert utxos_match_all?(rendered_2.outputs, tx_2.outputs)
    end
  end

  describe "render/2 with merge.json" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "renders merge transactions" do
      insert(:txoutput)
      _ = :txoutput |> insert(currency: @currency, owner: @alice, amount: 1)
      _ = :txoutput |> insert(currency: @currency, owner: @alice, amount: 1)
      _ = :txoutput |> insert(currency: @currency, owner: @alice, amount: 1)

      {:ok, merge_txs} = Transaction.merge(%{address: @alice, currency: @currency})
      IO.inspect(merge_txs)

      rendered = View.Transaction.render("merge.json", %{response: merge_txs})
      # TODO: not doing this right...
      assert 1 == 1
    end
  end

  defp utxos_match_all?(renders, originals) when length(renders) != length(originals), do: false

  defp utxos_match_all?(renders, originals) do
    original_utxo_positions =
      Enum.map(originals, fn utxo ->
        Utxo.position(utxo.blknum, utxo.txindex, utxo.oindex) |> Utxo.Position.encode()
      end)

    Enum.all?(renders, fn rendered -> rendered.utxo_pos in original_utxo_positions end)
  end
end
