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
  use OMG.Fixtures
  use Plug.Test

  alias OMG.State.Transaction
  alias OMG.Utxo
  alias OMG.Watcher.DB

  require Utxo
  import ExUnit.CaptureLog

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

  @tag fixtures: [:alice, :blocks_inserter]
  test "transaction metadata is persisted in database", %{alice: alice, blocks_inserter: blocks_inserter} do
    eth = OMG.Eth.RootChain.eth_pseudo_address()
    metadata = <<1::256>>

    [
      {1000, [OMG.TestHelper.create_recovered([{1, 0, 0, alice}], eth, [{alice, 300}], metadata)]}
    ]
    |> blocks_inserter.()

    assert metadata == DB.Transaction.get_by_position(1000, 0).metadata
  end

  @tag fixtures: [:initial_blocks]
  test "passing constrains out of allowed takes no effect and print a warning" do
    assert capture_log([level: :warn], fn ->
             [_tx] = DB.Transaction.get_by_filters(blknum: 2000, nothing: "there's no such thing")
           end) =~ "Constrain on :nothing does not exist in schema and was dropped from the query"
  end
end
