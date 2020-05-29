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

defmodule OMG.ChildChain.API.BlocksCacheTest do
  use ExUnit.Case

  alias OMG.ChildChain.API.BlocksCache
  alias OMG.ChildChain.API.BlocksCache.Storage
  alias OMG.ChildChain.Supervisor
  alias OMG.DB

  @block %{
    hash: <<56, 76, 203, 147, 17, 220, 122>>,
    number: 1000,
    transactions: [<<>>]
  }

  setup do
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

    :ok = Storage.ensure_ets_init(Supervisor.blocks_cache())

    db_updates_block =
      Enum.map(1..10, fn _ -> {:put, :block, Map.put(@block, :hash, :crypto.strong_rand_bytes(32))} end)

    DB.multi_update(db_updates_block)
    {:ok, pid} = BlocksCache.start_link(ets: Supervisor.blocks_cache())
    {:ok, %{pid: pid, blocks: db_updates_block}}
  end

  test "that concurrent access to the cache works", %{pid: _pid, blocks: blocks} do
    workers = Enum.count(blocks) + 100_000

    1..workers
    |> Task.async_stream(fn _ -> get_block(blocks) end,
      timeout: 5000,
      on_timeout: :kill_task,
      max_concurrency: 1000
    )
    |> Enum.map(fn {:ok, result} -> result end)

    # IO.puts(:sys.get_state(pid).cache_miss_counter)
    assert Enum.count(:ets.tab2list(Supervisor.blocks_cache())) == Enum.count(blocks)
  end

  defp get_block(blocks) do
    BlocksCache.get(elem(Enum.random(blocks), 2).hash)
  end
end
