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

defmodule OMG.Watcher.ReleaseTasks.InitKeyValueDBTest do
  use ExUnit.Case, async: true

  alias OMG.DB.ReleaseTasks.SetKeyValueDB
  alias OMG.Watcher.ReleaseTasks.InitKeyValueDB

  @apps [:logger, :crypto, :ssl]

  setup_all do
    _ = Enum.each(@apps, &Application.ensure_all_started/1)

    :ok
  end

  test "can't init non empty dir" do
    {:ok, dir} = Briefly.create(directory: true)
    :ok = System.put_env("DB_PATH", dir)

    _ = SetKeyValueDB.load([], release: :watcher)
    _ = InitKeyValueDB.run_multi()

    {:error, _} = InitKeyValueDB.run_multi()
    :ok = System.delete_env("DB_PATH")
    _ = File.rm_rf!(dir)
  end

  test "init for Watcher, with multilple dbs, servers start" do
    {:ok, dir} = Briefly.create(directory: true)
    :ok = System.put_env("DB_PATH", dir)

    _ = SetKeyValueDB.load([], release: :watcher)

    :ok = InitKeyValueDB.run_multi()

    # check default app's db path set correctly
    base_path = Application.fetch_env!(:omg_db, :path)
    assert base_path == "#{dir}/watcher"

    started_apps = Enum.map(Application.started_applications(), fn {app, _, _} -> app end)

    true =
      @apps
      |> Enum.map(fn app -> not Enum.member?(started_apps, app) end)
      |> Enum.all?()

    # start default application's database
    {:ok, _} = Application.ensure_all_started(:omg_db)

    # start exit processor database
    {:ok, _} =
      Supervisor.start_link(
        [OMG.DB.child_spec(db_path: base_path, instance: OMG.DB.Instance.ExitProcessor)],
        strategy: :one_for_one
      )

    assert OMG.DB.Instance.ExitProcessor |> GenServer.whereis() |> Kernel.is_pid()

    :ok = GenServer.stop(OMG.DB.Instance.ExitProcessor)
    :ok = Application.stop(:omg_db)
    :ok = System.delete_env("DB_PATH")
    _ = File.rm_rf!(dir)
  end
end
