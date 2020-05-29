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

defmodule OMG.ChildChain.BlocksCache.StorageTest do
  use ExUnit.Case

  alias OMG.ChildChain.API.BlocksCache.Storage
  alias OMG.DB

  @block %{
    hash: <<56, 76, 203, 147, 17, 220, 122>>,
    number: 1000,
    transactions: [<<>>]
  }

  setup_all do
    db_path = Briefly.create!(directory: true)
    Application.put_env(:omg_db, :path, db_path, persistent: true)

    :ok = DB.init(db_path)

    {:ok, started_apps} = Application.ensure_all_started(:omg_db)

    on_exit(fn ->
      Application.put_env(:omg_db, :path, nil)

      started_apps
      |> Enum.reverse()
      |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end)

    :ok
  end

  describe "get/2" do
    test "a not found block returns :not_found", %{test: test_name} do
      ets = :ets.new(test_name, [])
      assert Storage.get(<<"test_name_cache_blocks_test_1">>, ets) == :not_found
    end

    test "a found block is returned api formatted", %{test: test_name} do
      db_updates_block = {:put, :block, @block}
      DB.multi_update([db_updates_block])
      ets_ref = :ets.new(test_name, [])
      block = Storage.get(@block[:hash], ets_ref)
      assert is_map(block)
      assert ets_ref |> :ets.tab2list() |> hd() == {@block[:hash], block}
    end
  end
end
