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

defmodule OMG.DB.RocksDBCase do
  @moduledoc """
  Defines the useful common setup for all `...PersistenceTests`:
   - starts temporary file handler `:briefly`
   - creates temp dir with that
   - initializes the low-level LevelDB storage and starts the test DB server
  """

  use ExUnit.CaseTemplate
  alias OMG.DB.RocksDB.Server

  setup_all do
    :ok = Application.put_env(:omg_db, :type, :rocksdb, persistent: true)
    {:ok, _} = Application.ensure_all_started(:briefly)

    on_exit(fn ->
      :ok = Application.put_env(:omg_db, :type, :leveldb, persistent: true)
    end)

    :ok
  end

  setup %{test: test_name} do
    {:ok, dir} = Briefly.create(directory: true)
    :ok = Server.init_storage(dir)
    name = :"TestDB_#{test_name}"
    {:ok, pid} = start_supervised(OMG.DB.child_spec(db_path: dir, name: name))
    {:ok, %{db_dir: dir, db_pid: pid, db_pid_name: name}}
  end
end
