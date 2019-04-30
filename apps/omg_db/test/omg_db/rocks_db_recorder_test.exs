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

defmodule OMG.RocksDBRecorderTest do
  @moduledoc """
  A smoke test of the RocksDB support but for counters.
  """
  use ExUnitFixtures
  use OMG.DB.RocksDBCase, async: false
  alias OMG.DB

  test "if multi update counter gets incremented", %{db_pid: db_pid} do
    :ok = DB.multi_update([{:put, :block, %{hash: "xyz"}}], db_pid)

    {:links, pids} = Process.info(db_pid, :links)

    Enum.each(pids, fn pid ->
      case Process.info(pid, :registered_name) do
        {:registered_name, []} ->
          :pass

        {:registered_name, _} ->
          result = :ets.lookup(Map.get(:sys.get_state(pid), :table), :rocksdb_write)
          assert [rocksdb_write: 1] == result
      end
    end)
  end

  test "if read counter gets incremented", %{db_pid: db_pid} do
    _ = DB.spent_blknum(1, db_pid)
    {:links, pids} = Process.info(db_pid, :links)

    Enum.each(pids, fn pid ->
      case Process.info(pid, :registered_name) do
        {:registered_name, []} ->
          :pass

        {:registered_name, _} ->
          result = :ets.lookup(Map.get(:sys.get_state(pid), :table), :rocksdb_read)
          assert [rocksdb_read: 1] == result
      end
    end)
  end

  test "if multiread counter gets incremented", %{db_pid: db_pid} do
    _ = DB.utxos(db_pid)
    {:links, pids} = Process.info(db_pid, :links)

    Enum.each(pids, fn pid ->
      case Process.info(pid, :registered_name) do
        {:registered_name, []} ->
          :pass

        {:registered_name, _} ->
          result = :ets.lookup(Map.get(:sys.get_state(pid), :table), :rocksdb_multiread)
          assert [rocksdb_multiread: 1] == result
      end
    end)
  end
end
