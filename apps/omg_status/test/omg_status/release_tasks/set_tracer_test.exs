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

defmodule OMG.Status.ReleaseTasks.SetTracerTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog, only: [capture_log: 1]

  alias OMG.Status.Metric.Tracer
  alias OMG.Status.ReleaseTasks.SetTracer

  @app :omg_status
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
             # we set env to an empty string because disabled? is set to true!
             configuration = @app |> Application.get_env(Tracer) |> Keyword.put(:env, "") |> Enum.sort()
             tracer_config = config |> Keyword.get(@app) |> Keyword.get(Tracer) |> Enum.sort()
             assert configuration == tracer_config
           end)
  end

  test "if environment variables get applied in the statix configuration" do
    :ok = __MODULE__.System.put_env("DD_HOSTNAME", "cluster")
    :ok = __MODULE__.System.put_env("DD_PORT", "1919")
    :ok = __MODULE__.System.put_env("HOSTNAME", "this is my tracer test 1")
    :ok = __MODULE__.System.put_env("APP_ENV", "test 1")

    assert capture_log(fn ->
             config = SetTracer.load([], release: :test_case_1, system_adapter: __MODULE__.System)
             port = config |> Keyword.fetch!(:statix) |> Keyword.fetch!(:port)
             host = config |> Keyword.fetch!(:statix) |> Keyword.fetch!(:host)
             tags = config |> Keyword.fetch!(:statix) |> Keyword.fetch!(:tags)
             assert host == "cluster"
             assert port == 1919
             assert Enum.member?(tags, "app_env:test 1") == true
           end)
  end

  test "if default statix configuration is used when there's no environment variables" do
    app_env = "test 2"
    hostname = "this is my tracer test 2"
    :ok = __MODULE__.System.put_env("HOSTNAME", hostname)
    :ok = __MODULE__.System.put_env("APP_ENV", app_env)
    configuration = SetTracer.load([], release: :test_case_2, system_adapter: __MODULE__.System)
    tags = configuration |> Keyword.fetch!(:statix) |> Keyword.fetch!(:tags)
    assert tags == ["application:test_case_2", "app_env:#{app_env}", "hostname:#{hostname}"]
  end

  test "if environment variables get applied in the spandex_datadog configuration" do
    :ok = __MODULE__.System.put_env("DD_HOSTNAME", "cluster")
    :ok = __MODULE__.System.put_env("DD_APM_PORT", "1919")
    :ok = __MODULE__.System.put_env("BATCH_SIZE", "7000")
    :ok = __MODULE__.System.put_env("SYNC_THRESHOLD", "900")
    :ok = __MODULE__.System.put_env("HOSTNAME", "this is my tracer test 4")

    capture_log(fn ->
      config = SetTracer.load([], system_adapter: __MODULE__.System)
      port = config |> Keyword.fetch!(:spandex_datadog) |> Keyword.fetch!(:port)
      host = config |> Keyword.fetch!(:spandex_datadog) |> Keyword.fetch!(:host)
      batch_size = config |> Keyword.fetch!(:spandex_datadog) |> Keyword.fetch!(:batch_size)
      sync_threshold = config |> Keyword.fetch!(:spandex_datadog) |> Keyword.fetch!(:sync_threshold)
      assert port == 1919
      assert host == "cluster"
      assert batch_size == 7000
      assert sync_threshold == 900
    end)
  end

  test "if default spandex_datadog configuration is used when there's no environment variables" do
    :ok = __MODULE__.System.put_env("HOSTNAME", "this is my tracer test 5")
    config = SetTracer.load([], system_adapter: __MODULE__.System)
    configuration = Application.get_all_env(:spandex_datadog)
    sorted_configuration = configuration |> Enum.sort() |> Keyword.drop([:http])
    spandex_datadog_config = Keyword.fetch!(config, :spandex_datadog)
    assert sorted_configuration == Enum.sort(spandex_datadog_config)
  end

  test "if exit is thrown when faulty configuration is used" do
    :ok = __MODULE__.System.put_env("DD_DISABLED", "TRUEeee")
    catch_exit(SetTracer.load([], system_adapter: __MODULE__.System))
  end

  test "if exit is thrown when faulty configuration for hostname is used" do
    :ok = __MODULE__.System.put_env("DD_DISABLED", "TRUE")
    :ok = __MODULE__.System.put_env("APP_ENV", "YOLO")
    assert catch_exit(SetTracer.load([], system_adapter: __MODULE__.System)) == "HOSTNAME is not set correctly."
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
