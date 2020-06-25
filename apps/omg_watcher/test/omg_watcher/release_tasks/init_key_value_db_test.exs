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

  alias OMG.Watcher.ReleaseTasks.InitKeyValueDB
  alias OMG.DB.ReleaseTasks.SetKeyValueDB

  @apps [:logger, :crypto, :ssl]

  setup_all do
    _ = Enum.each(@apps, &Application.ensure_all_started/1)

    on_exit(fn ->
      @apps |> Enum.reverse() |> Enum.each(&Application.stop/1)
    end)

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
    app_path = Application.fetch_env!(:omg_db, :path)
    assert app_path == "#{dir}/watcher/app"

    started_apps = Enum.map(Application.started_applications(), fn {app, _, _} -> app end)

    true =
      @apps
      |> Enum.map(fn app -> not Enum.member?(started_apps, app) end)
      |> Enum.all?()

    # start default application's database
    {:ok, _} = Application.ensure_all_started(:omg_db)

    # start exit processor database
    exit_processor_dir_path = Path.join([OMG.DB.root_path(app_path), "exit_processor"])
    {:ok, pid} = OMG.DB.start_link(db_path: exit_processor_dir_path, name: TestExitProcessorDB)
    assert pid == GenServer.whereis(TestExitProcessorDB)

    :ok = GenServer.stop(TestExitProcessorDB)
    :ok = Application.stop(:omg_db)
    :ok = System.delete_env("DB_PATH")
    _ = File.rm_rf!(dir)
  end
end
