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

defmodule OMG.Watcher.ReleaseTasks.SetTracerTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog, only: [capture_log: 1]

  alias OMG.Watcher.ReleaseTasks.SetTracer
  alias OMG.Watcher.Tracer
  @app :omg_watcher

  setup do
    {:ok, pid} = __MODULE__.System.start_link([])
    nil = Process.put(__MODULE__.System, pid)
    :ok
  end

  test "if environment variables get applied in the configuration" do
    :ok = __MODULE__.System.put_env("DD_DISABLED", "TRUE")
    :ok = __MODULE__.System.put_env("APP_ENV", "YOLO")
    :ok = __MODULE__.System.put_env("HOSTNAME", "this is my tracer test 3")

    assert capture_log(fn ->
             config = SetTracer.load([], system_adapter: __MODULE__.System)
             disabled = config |> Keyword.fetch!(@app) |> Keyword.fetch!(Tracer) |> Keyword.fetch!(:disabled?)
             env = config |> Keyword.fetch!(@app) |> Keyword.fetch!(Tracer) |> Keyword.fetch!(:env)

             assert disabled == true
             # if it's disabled, env doesn't matter, so we set it to an empty string
             assert env == ""
           end)
  end

  test "if default configuration is used when there's no environment variables" do
    :ok = __MODULE__.System.put_env("HOSTNAME", "this is my tracer test 3")

    assert capture_log(fn ->
             config = SetTracer.load([], system_adapter: __MODULE__.System)
             configuration = @app |> Application.get_env(Tracer) |> Keyword.put(:env, "") |> Enum.sort()
             tracer_config = config |> Keyword.get(@app) |> Keyword.get(Tracer) |> Enum.sort()
             assert configuration == tracer_config
           end)
  end

  test "if exit is thrown when faulty configuration is used" do
    :ok = __MODULE__.System.put_env("DD_DISABLED", "TRUEeee")
    catch_exit(SetTracer.load([], system_adapter: __MODULE__.System))
  end

  defmodule System do
    def start_link(args), do: GenServer.start_link(__MODULE__, args, [])
    def get_env(key), do: __MODULE__ |> Process.get() |> GenServer.call({:get_env, key})
    def put_env(key, value), do: __MODULE__ |> Process.get() |> GenServer.call({:put_env, key, value})
    def init(_), do: {:ok, %{}}

    def handle_call({:get_env, key}, _, state) do
      {:reply, state[key], state}
    end

    def handle_call({:put_env, key, value}, _, state) do
      {:reply, :ok, Map.put(state, key, value)}
    end
  end
end
