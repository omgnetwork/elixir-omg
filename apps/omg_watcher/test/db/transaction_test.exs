# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.Watcher.DB.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.API.Fixtures
  use Plug.Test

  alias OMG.API.State.Transaction
  alias OMG.API.Utxo
  alias OMG.Watcher.DB

  require Utxo

  describe "get_by_filters/3" do
    @tag fixtures: [:alice, :initial_blocks]
    test "gets all transactions for an address", %{alice: alice} do
      transactions = DB.Transaction.get_by_filters(alice.addr, nil, nil)

      assert length(transactions) == 5
    end

    @tag fixtures: [:alice, :initial_blocks]
    test "gets all transactions for an address with limit = 1", %{alice: alice} do
      transactions = DB.Transaction.get_by_filters(alice.addr, nil, 1)

      assert length(transactions) == 1
    end
  end

  @tag fixtures: [:initial_blocks]
  test "verifies all expected transaction were inserted", %{initial_blocks: initial_blocks} do
    initial_blocks
    |> Enum.each(fn {blknum, txindex, txhash, recovered_tx} ->
      %Transaction.Recovered{signed_tx: %Transaction.Signed{signed_tx_bytes: txbytes}} = recovered_tx

      assert %DB.Transaction{
               txhash: ^txhash,
               blknum: ^blknum,
               txindex: ^txindex,
               txbytes: ^txbytes
             } = DB.Transaction.get(txhash)
    end)
  end

  @tag fixtures: [:initial_blocks]
  test "gets all transactions from a block", %{initial_blocks: initial_blocks} do
    [tx0, tx1] = DB.Transaction.get_by_blknum(3000)

    tx_hashes =
      initial_blocks
      |> Enum.filter(&(elem(&1, 0) == 3000))
      |> Enum.map(&elem(&1, 2))

    assert tx_hashes == [tx0, tx1] |> Enum.map(& &1.txhash)

    assert [] == DB.Transaction.get_by_blknum(5000)
  end
end
