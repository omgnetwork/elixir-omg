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

defmodule OMG.WatcherInfo.ReleaseTasks.SetTracerTest do
  use ExUnit.Case, async: false
  alias OMG.WatcherInfo.ReleaseTasks.SetTracer
  alias OMG.WatcherInfo.Tracer
  @app :omg_watcher_info
  @configuration_old Application.get_env(@app, Tracer)

  setup do
    on_exit(fn ->
      # configuration is global state so we reset it to known values in case
      # it got fiddled before
      :ok = Application.put_env(@app, Tracer, @configuration_old, persistent: true)
    end)

    :ok
  end

  test "if environment variables get applied in the configuration" do
    :ok = System.put_env("DD_DISABLED", "TRUE")
    :ok = System.put_env("APP_ENV", "YOLO")
    :ok = SetTracer.load([], [])
    configuration = Application.get_env(@app, Tracer)
    disabled_updated = configuration[:disabled?]
    env_updated = configuration[:env]
    true = disabled_updated
    "YOLO" = env_updated

    ^configuration =
      @configuration_old
      |> Keyword.put(:disabled?, true)
      |> Keyword.put(:env, "YOLO")
  end

  test "if default configuration is used when there's no environment variables" do
    :ok = System.delete_env("DD_DISABLED")
    :ok = System.put_env("APP_ENV", "YOLO")
    :ok = SetTracer.load([], [])
    configuration = Application.get_env(@app, Tracer)
    sorted_configuration = Enum.sort(configuration)
    assert sorted_configuration == @configuration_old |> Keyword.put(:env, "YOLO") |> Enum.sort()
  end

  test "if exit is thrown when faulty configuration is used" do
    :ok = System.put_env("DD_DISABLED", "TRUEeee")
    catch_exit(SetTracer.load([], []))
    :ok = System.delete_env("DD_DISABLED")
  end
end
