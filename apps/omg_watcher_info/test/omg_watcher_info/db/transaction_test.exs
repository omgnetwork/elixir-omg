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

defmodule OMG.WatcherInfo.DB.TransactionTest do
  @moduledoc """
  Currently, this test focuses on testing behaviors not testable via Controllers.TransactionTest.

  The reason is that we are treating the DB schema etc. as implementation detail. In case testing through controllers
  becomes hard/slow or otherwise unreasnable, refactor these two kinds of tests appropriately
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures
  use Plug.Test

  alias OMG.Utils.Paginator
  alias OMG.Utxo
  alias OMG.WatcherInfo.DB

  require Utxo
  import ExUnit.CaptureLog

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @tag fixtures: [:initial_blocks]
  test "the associated block can be preloaded" do
    preloaded =
      DB.Transaction.get_by_position(3000, 1)
      |> DB.Repo.preload(:block)

    assert %DB.Transaction{
             blknum: 3000,
             txindex: 1,
             block: %DB.Block{blknum: 3000}
           } = preloaded
  end

  @tag fixtures: [:initial_blocks]
  test "gets all transactions from a block", %{initial_blocks: initial_blocks} do
    # this test is here to ensure that calls coming from places other than `transaction` controllers are covered
    [tx0, tx1] = DB.Transaction.get_by_blknum(3000)

    tx_hashes =
      initial_blocks
      |> Enum.filter(&(elem(&1, 0) == 3000))
      |> Enum.map(&elem(&1, 2))

    assert tx_hashes == [tx0, tx1] |> Enum.map(& &1.txhash)

    assert [] == DB.Transaction.get_by_blknum(5000)
  end

  @tag fixtures: [:initial_blocks]
  test "passing constrains out of allowed takes no effect and print a warning" do
    assert capture_log([level: :warn], fn ->
             DB.Transaction.get_by_filters(
               [blknum: 2000, nothing: "there's no such thing"],
               %Paginator{}
             )
           end) =~
             "Constraint on :nothing does not exist in schema and was dropped from the query"
  end

  describe "get_count/0" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns a correct transaction count" do
      alice = OMG.TestHelper.generate_entity()
      bob = OMG.TestHelper.generate_entity()
      tx_1 = OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 300}])
      tx_2 = OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 500}])

      mined_block = %{
        transactions: [tx_1, tx_2],
        blknum: 1000,
        blkhash: "0x1000",
        timestamp: 1_576_500_000,
        eth_height: 1
      }

      _ = DB.Block.insert_with_transactions(mined_block)

      tx_count = DB.Transaction.get_count()

      assert tx_count == 2
    end
  end

  describe "get_count_last_24_hour/0" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns correct count if transactions have been made in the last twenty four hours" do
      now = DateTime.to_unix(DateTime.utc_now())
      twenty_four_hours = 86400

      alice = OMG.TestHelper.generate_entity()
      bob = OMG.TestHelper.generate_entity()
      tx_1 = OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 300}])
      tx_2 = OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 500}])

      mined_block = %{
        transactions: [tx_1, tx_2],
        blknum: 1000,
        blkhash: "0x1000",
        timestamp: now - twenty_four_hours + 100,
        eth_height: 1
      }

      _ = DB.Block.insert_with_transactions(mined_block)

      tx_count = DB.Transaction.get_count_last_24_hour()

      assert tx_count == 2
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns correct count if no transactions have been made in the last twenty four hours" do
      now = DateTime.to_unix(DateTime.utc_now())
      twenty_four_hours = 86400

      alice = OMG.TestHelper.generate_entity()
      bob = OMG.TestHelper.generate_entity()
      tx_1 = OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 300}])
      tx_2 = OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 500}])

      mined_block = %{
        transactions: [tx_1, tx_2],
        blknum: 1000,
        blkhash: "0x1000",
        timestamp: now - twenty_four_hours - 100,
        eth_height: 1
      }

      _ = DB.Block.insert_with_transactions(mined_block)

      tx_count = DB.Transaction.get_count_last_24_hour()

      assert tx_count == 0
    end
  end
end
