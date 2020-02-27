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

defmodule OMG.WatcherInfo.DB.RepoTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures

  import OMG.WatcherInfo.Factory

  alias OMG.WatcherInfo.DB

  alias OMG.Utxo
  require Utxo

  describe "DB.Repo.insert_all_chunked/3" do
    # The current number of columns on the transaction table allow up to 8191
    # transactions to be inserted using `DB.Repo.insert_all/3` before chunking must
    # be done to avoid hitting postgres limits. The test `DB.Repo.insert_all for
    # transactions (via postgres INSERT)...` below shows how this number is derived
    # and asserts the number is correct
    @max_txns_before_chunking 8191   # aka chunk_size for the transactions table

    # A special test for insert_all_chunked/3 is here because under the hood it calls insert_all/2. Using
    # insert_all/3 with a queryable means that certain autogenerated columns, such as inserted_at and
    # updated_at, will not be inserted as they would be if you used a plain insert. More info
    # is here: https://hexdocs.pm/ecto/Ecto.Repo.html#c:insert_all/3
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "insert_all_chunked adds inserted_at and updated_at timestamps correctly" do
      txoutput =
        params_for(:txoutput)
        |> Map.drop([:ethevents])

      DB.Repo.insert_all_chunked(OMG.WatcherInfo.DB.TxOutput, [txoutput])

      txoutput_with_dates =
        DB.TxOutput.get_by_position(Utxo.position(txoutput.blknum, txoutput.txindex, txoutput.oindex))

      assert txoutput_with_dates.inserted_at != nil
      assert DateTime.compare(txoutput_with_dates.inserted_at, txoutput_with_dates.updated_at) == :eq
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "insert_all_chunked/3 does not exceed postgres' max of 65535 parameters" do
      block = insert(:block)

      # Create an array of transactions beyond postgres limits where chunking
      # is required.
      transactions = new_transactions(block.blknum, @max_txns_before_chunking + 1)

      assert DB.Repo.insert_all_chunked(OMG.WatcherInfo.DB.Transaction, transactions) == :ok
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "chunk_size/1 calculates the correct chunk size based on the column's in the transaction table" do
      block = insert(:block)

      transaction = new_transaction(block.blknum, 1, DateTime.utc_now())

      assert DB.Repo.chunk_size(transaction) == @max_txns_before_chunking
    end
  end

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "DB.Repo.insert_all for transactions (via postgres INSERT) is limited to #{@max_txns_before_chunking} transactions" do
    utc_now = DateTime.utc_now()

    # test that transaction inseration at the max limit succeeds
    block = insert(:block)
    transactions = new_transactions(block.blknum, @max_txns_before_chunking, utc_now)

    {transactions_inserted, _} = DB.Repo.insert_all(OMG.WatcherInfo.DB.Transaction, transactions)

    assert transactions_inserted == @max_txns_before_chunking

    # test that transaction inseration above the max limit raises an exception
    block = insert(:block)
    transactions = new_transactions(block.blknum, @max_txns_before_chunking + 1, utc_now)

    assert_raise(
      Postgrex.QueryError,
      "postgresql protocol can not handle 65536 parameters, the maximum is 65535",
      fn -> DB.Repo.insert_all(OMG.WatcherInfo.DB.Transaction, transactions) end
    )
  end

  describe "DB.Repo timestamps" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "all tables have inserted_at and updated_at timestamps set correctly on inserts and udpates" do
      Enum.each([:block, :transaction, :txoutput, :ethevent], fn row ->
        row = insert(row)

        assert row.inserted_at != nil
        assert DateTime.compare(row.inserted_at, row.updated_at) == :eq

        {:ok, row} = DB.Repo.update(Ecto.Changeset.change(row), [{:force, true}])

        assert DateTime.compare(row.inserted_at, row.updated_at) == :lt
      end)
    end
  end

  # Prefer using `ExMachina.build_list/3 which uses `OMG.WatcherInfo.Factory.Transaction`
  # over this function. This function is built to be fast and simple.
  defp new_transactions(blknum, count, utc_now \\ nil) do
    Enum.reduce(1..count, [], fn index, acc ->
      [new_transaction(blknum, index, utc_now) | acc]
    end)
  end

  # Prefer using `ExMachina.build/2 which uses `OMG.WatcherInfo.Factory.Transaction`
  # over this function. This function is built to be fast and simple.
  #
  # `ExMachina.params_for/2` could be used here to make use of `OMG.WatcherInfo.Factory.Transaction`.
  # But the transaction factory does a lot of extra stuff unnecessary for this test. This stripped
  # down version is about 15x faster. Also using `ExMachina.params_for/2` here also requires some
  # tweaking of the map it returns because `OMG.WatcherInfo.DB.Repo.insert_all_chunked` is the code
  # being tested rather than `Ecto.Repo.insert_all/3`. The 2 functions differ in the inputs they
  # expect.
  defp new_transaction(blknum, index, utc_now) do
    transaction = %{
      txhash: to_string(index),
      txindex: index,
      txbytes: to_string(index),
      metadata: to_string(index),
      txtype: 1,
      blknum: blknum
    }

    if utc_now != nil do
      Map.merge(transaction, %{inserted_at: utc_now, updated_at: utc_now})
    else
      transaction
    end
  end
end
