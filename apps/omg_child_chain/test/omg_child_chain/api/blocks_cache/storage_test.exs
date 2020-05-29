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

  alias OMG.ChildChain.BlocksCache.Storage
  alias OMG.DB

  @block %{
    hash:
      <<56, 76, 203, 147, 17, 220, 122, 120, 218, 181, 235, 179, 15, 208, 70, 105, 182, 240, 18, 92, 51, 55, 210, 139,
        69, 236, 52, 3, 96, 145, 115, 237>>,
    number: 1000,
    transactions: [
      <<248, 232, 248, 67, 184, 65, 110, 181, 0, 211, 50, 32, 144, 133, 196, 149, 27, 99, 215, 25, 28, 202, 179, 50,
        125, 54, 174, 81, 95, 218, 232, 21, 240, 94, 135, 98, 151, 100, 2, 192, 9, 20, 142, 29, 152, 219, 238, 249, 86,
        217, 114, 137, 254, 94, 179, 118, 6, 118, 112, 200, 29, 164, 234, 159, 61, 53, 142, 192, 25, 171, 27, 1, 225,
        160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 59, 154, 202, 0, 248,
        92, 237, 1, 235, 148, 166, 206, 94, 109, 45, 68, 169, 48, 98, 25, 3, 103, 74, 46, 77, 130, 75, 178, 230, 4, 148,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 237, 1, 235, 148, 49, 76, 129, 83, 204, 241, 205,
        219, 107, 202, 91, 126, 124, 118, 195, 198, 125, 55, 171, 6, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 2, 128, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0>>,
      <<248, 232, 248, 67, 184, 65, 197, 59, 241, 160, 247, 160, 94, 42, 3, 174, 71, 177, 70, 223, 169, 153, 130, 213,
        196, 117, 3, 171, 10, 36, 147, 195, 72, 28, 33, 139, 151, 238, 58, 151, 66, 5, 174, 113, 212, 195, 172, 239, 89,
        127, 65, 135, 181, 254, 26, 72, 140, 168, 96, 214, 159, 241, 65, 215, 81, 88, 97, 195, 231, 143, 28, 1, 225,
        160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 119, 53, 148, 0, 248,
        92, 237, 1, 235, 148, 166, 206, 94, 109, 45, 68, 169, 48, 98, 25, 3, 103, 74, 46, 77, 130, 75, 178, 230, 4, 148,
        221, 40, 96, 221, 143, 24, 47, 144, 135, 3, 131, 169, 141, 218, 246, 63, 219, 0, 87, 62, 6, 237, 1, 235, 148,
        49, 76, 129, 83, 204, 241, 205, 219, 107, 202, 91, 126, 124, 118, 195, 198, 125, 55, 171, 6, 148, 221, 40, 96,
        221, 143, 24, 47, 144, 135, 3, 131, 169, 141, 218, 246, 63, 219, 0, 87, 62, 2, 128, 160, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
      <<248, 82, 192, 3, 238, 237, 2, 235, 148, 222, 173, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 148, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 160, 61, 119, 206, 68, 25, 203, 29, 23, 147, 224,
        136, 32, 198, 128, 177, 74, 227, 250, 194, 173, 146, 182, 251, 152, 123, 172, 26, 83, 175, 194, 213, 238>>,
      <<248, 82, 192, 3, 238, 237, 2, 235, 148, 222, 173, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 148,
        221, 40, 96, 221, 143, 24, 47, 144, 135, 3, 131, 169, 141, 218, 246, 63, 219, 0, 87, 62, 2, 160, 213, 91, 93,
        28, 192, 71, 222, 57, 85, 6, 14, 161, 93, 43, 26, 186, 64, 115, 241, 154, 153, 187, 42, 158, 100, 117, 89, 187,
        64, 107, 55, 120>>
    ]
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
