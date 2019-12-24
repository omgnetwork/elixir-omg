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

defmodule OMG.WatcherInfo.DB.TxOutputTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures

  alias OMG.Utils.Paginator

  import OMG.WatcherInfo.Factory

  alias OMG.Utxo
  alias OMG.WatcherInfo.DB

  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @tag fixtures: [:phoenix_ecto_sandbox, :alice]
  test "transaction output schema handles big numbers properly", %{alice: alice} do
    power_of_2 = fn n -> :lists.duplicate(n, 2) |> Enum.reduce(&(&1 * &2)) end
    assert 16 == power_of_2.(4)

    big_amount = power_of_2.(256) - 1

    DB.Block.insert_with_transactions(%{
      transactions: [OMG.TestHelper.create_recovered([], @eth, [{alice, big_amount}])],
      blknum: 11_000,
      blkhash: <<?#::256>>,
      timestamp: :os.system_time(:second),
      eth_height: 10
    })

    utxo = DB.TxOutput.get_by_position(Utxo.position(11_000, 0, 0))
    assert not is_nil(utxo)
    assert utxo.amount == big_amount
  end

  describe "get_deposits/1" do
  @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns a list of deposits" do
    #    _ = insert(:block, blknum: 1000, hash: "0x1000", eth_height: 1, timestamp: 100)
    #      _ = insert(:block, blknum: 2000, hash: "0x2000", eth_height: 2, timestamp: 200)
    #    _ = insert(:block, blknum: 3000, hash: "0x3000", eth_height: 3, timestamp: 300)

       paginator = %Paginator{
         data: [],
           data_paging: %{
           limit: 10,
           page: 1
         }
       }

      results = DB.TxOutput.get_deposits(paginator)

      assert length(results.data) == 3
      assert Enum.all?(results.data, fn txoutput -> %DB.TxOutput{} = txoutput end)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns a list of deposits sorted by descending blknum" do
#    _ = insert(:block, blknum: 1000, hash: "0x1000", eth_height: 1, timestamp: 100)
#    _ = insert(:block, blknum: 2000, hash: "0x2000", eth_height: 2, timestamp: 200)
#    _ = insert(:block, blknum: 3000, hash: "0x3000", eth_height: 3, timestamp: 300)

      paginator = %Paginator{
        data: [],
        data_paging: %{
          limit: 10,
          page: 1
        }
      }

      results = DB.TxOutput.get_deposits(paginator)

      assert length(results.data) == 3
#      assert results.data |> Enum.at(0) |> Map.get(:blknum) == 3000
#      assert results.data |> Enum.at(1) |> Map.get(:blknum) == 2000
#      assert results.data |> Enum.at(2) |> Map.get(:blknum) == 1000
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns a list of deposits filtered by address" do
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns an empty list when given limit: 0" do
      paginator = %Paginator{
        data: [],
        data_paging: %{
          limit: 0,
          page: 1
        }
      }

      results = DB.TxOutput.get_deposits(paginator)

      assert results.data == []
    end
  end
end
