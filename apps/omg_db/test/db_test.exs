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

defmodule OMG.DBTest do
  @moduledoc """
  A smoke test of the LevelDB support (temporary, remove if it breaks too often)

  Note the excluded moduletag, this test requires an explicit `--include`

  NOTE: it broke, but fixed easily, still useful, since integration test is thin still
  """
  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias OMG.DB

  @moduletag :wrappers

  setup_all do
    {:ok, _} = Application.ensure_all_started(:briefly)
    :ok
  end

  setup do
    {:ok, dir} = Briefly.create(directory: true)

    {:ok, pid} =
      GenServer.start_link(
        OMG.DB.LevelDBServer,
        %{db_path: dir},
        name: TestDBServer
      )

    on_exit(fn ->
      try do
        GenServer.stop(pid)
      catch
        :exit, _ -> :yeah_it_has_already_stopped
      end
    end)

    {:ok, %{dir: dir}}
  end

  test "handles block storage", %{dir: dir} do
    :ok =
      DB.multi_update(
        [
          {:put, :block, %{hash: "xyz"}},
          {:put, :block, %{hash: "vxyz"}},
          {:put, :block, %{hash: "wvxyz"}}
        ],
        TestDBServer
      )

    assert {:ok, [%{hash: "wvxyz"}, %{hash: "xyz"}]} == DB.blocks(["wvxyz", "xyz"], TestDBServer)

    :ok =
      DB.multi_update(
        [
          {:delete, :block, %{hash: "xyz"}}
        ],
        TestDBServer
      )

    checks = fn ->
      assert {:ok, [%{hash: "wvxyz"}, :not_found, %{hash: "vxyz"}]} == DB.blocks(["wvxyz", "xyz", "vxyz"], TestDBServer)
    end

    checks.()

    # check actual persistence
    restart(dir)
    checks.()
  end

  test "handles utxo storage and that it actually persists", %{dir: dir} do
    :ok =
      DB.multi_update(
        [
          {:put, :utxo, {{10, 30, 0}, %{amount: 10, owner: "alice1"}}},
          {:put, :utxo, {{11, 30, 0}, %{amount: 10, owner: "alice2"}}},
          {:put, :utxo, {{11, 31, 0}, %{amount: 10, owner: "alice3"}}},
          {:put, :utxo, {{11, 31, 1}, %{amount: 10, owner: "alice4"}}},
          {:put, :utxo, {{50, 30, 0}, %{amount: 10, owner: "alice5"}}},
          {:delete, :utxo, {50, 30, 0}}
        ],
        TestDBServer
      )

    checks = fn ->
      assert {:ok,
              [
                {{10, 30, 0}, %{amount: 10, owner: "alice1"}},
                {{11, 30, 0}, %{amount: 10, owner: "alice2"}},
                {{11, 31, 0}, %{amount: 10, owner: "alice3"}},
                {{11, 31, 1}, %{amount: 10, owner: "alice4"}}
              ]} == DB.utxos(TestDBServer)
    end

    checks.()

    # check actual persistence
    restart(dir)
    checks.()
  end

  defp restart(dir) do
    :ok = GenServer.stop(TestDBServer)

    {:ok, _pid} =
      GenServer.start_link(
        OMG.DB.LevelDBServer,
        %{db_path: dir},
        name: TestDBServer
      )
  end

  test "handles last exit height storage" do
    :ok =
      DB.multi_update(
        [
          {:put, :last_fast_exit_eth_height, 12},
          {:put, :last_slow_exit_eth_height, 10}
        ],
        TestDBServer
      )

    assert {:ok, 12} == DB.last_fast_exit_eth_height(TestDBServer)
    assert {:ok, 10} == DB.last_slow_exit_eth_height(TestDBServer)
  end
end
