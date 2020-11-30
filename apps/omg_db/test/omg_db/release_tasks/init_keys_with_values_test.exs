# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.DB.ReleaseTasks.InitKeysWithValuesTest do
  use ExUnit.Case, async: false
  alias OMG.DB.ReleaseTasks.InitKeysWithValues
  alias OMG.DB.RocksDB
  alias OMG.DB.RocksDB.Server

  setup do
    {:ok, dir} = Briefly.create(directory: true)
    :ok = Server.init_storage(dir)
    :ok = Application.put_env(:omg_db, :path, dir, persistent: true)
    {:ok, started_apps} = Application.ensure_all_started(:omg_db)

    on_exit(fn ->
      :ok = Application.put_env(:omg_db, :path, nil)
      Enum.map(started_apps, fn app -> _ = Application.stop(app) end)
    end)

    {:ok, %{}}
  end

  test ":last_ife_exit_deleted_eth_height is set if it wasn't set previously" do
    :ok = RocksDB.multi_update([{:delete, :last_ife_exit_deleted_eth_height, 0}])

    assert InitKeysWithValues.run() == :ok
    assert RocksDB.get_single_value(:last_ife_exit_deleted_eth_height) == {:ok, 0}
  end

  test "value under :last_ife_exit_deleted_eth_height is not changed if it was already set" do
    initial_value = 5
    :ok = RocksDB.multi_update([{:put, :last_ife_exit_deleted_eth_height, initial_value}])

    assert InitKeysWithValues.run() == :ok
    assert RocksDB.get_single_value(:last_ife_exit_deleted_eth_height) == {:ok, initial_value}
  end

  test "does not fail when omg db is not started" do
    :ok = Application.stop(:omg_db)
    :ok = Application.put_env(:omg_db, :path, nil)

    assert InitKeysWithValues.run() == :ok
  end
end
