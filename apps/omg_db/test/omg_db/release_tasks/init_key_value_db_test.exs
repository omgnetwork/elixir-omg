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

defmodule OMG.DB.ReleaseTasks.InitKeyValueDBTest do
  use ExUnit.Case, async: false
  alias OMG.DB.ReleaseTasks.InitKeyValueDB
  alias OMG.DB.ReleaseTasks.SetKeyValueDB

  @apps [:logger, :crypto, :ssl]

  setup_all do
    on_exit(fn ->
      _ = Enum.each(@apps, &Application.ensure_all_started/1)
    end)

    :ok
  end

  test "init works and DB starts" do
    {:ok, dir} = Briefly.create(directory: true)
    :ok = System.put_env("DB_PATH", dir)
    :ok = SetKeyValueDB.load([],release: :child_chain)
    :ok = InitKeyValueDB.run()
    started_apps = Enum.map(Application.started_applications(), fn {app, _, _} -> app end)
    [true, true, true] = Enum.map(@apps, fn app -> not Enum.member?(started_apps, app) end)
    {:ok, _} = Application.ensure_all_started(:omg_db)
    :ok = Application.stop(:omg_db)
    :ok = System.delete_env("DB_PATH")
  end

  test "can't init non empty dir" do
    {:ok, dir} = Briefly.create(directory: true)
    :ok = System.put_env("DB_PATH", dir)
    :ok = SetKeyValueDB.load([],release: :watcher)

    _ = InitKeyValueDB.run()

    {:error, _} = InitKeyValueDB.run()
    :ok = System.delete_env("DB_PATH")
  end

  test "if init isn't called, DB doesn't start" do
    _ = Application.stop(:omg_db)
    {:ok, dir} = Briefly.create(directory: true)
    :ok = System.put_env("DB_PATH", dir)
    :ok = SetKeyValueDB.load([],release: :child_chain)

    try do
      {:ok, _} = Application.ensure_all_started(:omg_db)
    catch
      _,
      {:badmatch,
       {:error,
        {:omg_db,
         {{:shutdown, {:failed_to_start_child, _, {:bad_return_value, {:error, {:db_open, _}}}}},
          {OMG.DB.Application, :start, [:normal, []]}}}}} ->
        :ok
    end

    :ok = System.delete_env("DB_PATH")
  end
end
