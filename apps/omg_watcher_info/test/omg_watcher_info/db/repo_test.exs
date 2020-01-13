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

defmodule OMG.WatcherInfo.DB.RepoTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures

  import Ecto.Query

  import OMG.WatcherInfo.Factory

  alias OMG.WatcherInfo.DB

  alias OMG.Utxo
  require Utxo

  describe "DB.Repo.insert_all_chunked/3" do
    # a special test for insert_all_chunked/3 is here because under the hood it calls insert_all/2. using
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
  end

  describe "DB.Repo timestamps" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "all tables have inserted_at and updated_at timestamps set correctly" do
      Enum.each([:block, :transaction, :txoutput, :ethevent], fn row ->
        row = insert(row)

        assert row.inserted_at != nil
        assert DateTime.compare(row.inserted_at, row.updated_at) == :eq

        {:ok, row} = DB.Repo.update(Ecto.Changeset.change(row), [{:force, true}])

        assert DateTime.compare(row.inserted_at, row.updated_at) == :lt
      end)
    end
  end
end
