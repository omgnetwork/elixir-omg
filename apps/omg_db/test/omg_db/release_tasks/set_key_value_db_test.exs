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

defmodule OMG.DB.ReleaseTasks.SetKeyValueDBTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog, only: [capture_log: 1]
  alias OMG.DB.ReleaseTasks.SetKeyValueDB

  @app :omg_db

  setup do
    on_exit(fn ->
      :ok = System.delete_env("DB_PATH")
    end)

    :ok
  end

  test "if environment variables get applied in the configuration" do
    test_path = "/tmp/YOLO/"
    release = :watcher_info
    :ok = System.put_env("DB_PATH", test_path)

    capture_log(fn ->
      config = SetKeyValueDB.load([], release: release)
      path = config |> Keyword.fetch!(@app) |> Keyword.fetch!(:path)
      assert path == test_path <> "#{release}"
    end)
  end

  test "if default configuration is used when there's no environment variables" do
    :ok = System.delete_env("DB_PATH")

    capture_log(fn ->
      config = SetKeyValueDB.load([], release: :watcher_info)
      path = config |> Keyword.fetch!(@app) |> Keyword.fetch!(:path)

      assert path == Path.join([System.get_env("HOME"), ".omg/data"]) <> "/watcher_info"
    end)
  end
end
