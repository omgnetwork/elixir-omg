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
  use ExUnit.Case, async: false
  alias OMG.Status.Metric.Tracer
  alias OMG.Status.ReleaseTasks.SetTracer

  @app :omg_status
  @configuration_old Application.get_env(@app, Tracer)
  @configuration_old_statix Application.get_all_env(:statix)
  @configuration_old_spandex_datadog Application.get_all_env(:spandex_datadog)
  setup do
    :ok = Application.put_env(:statix, :host, Keyword.get(@configuration_old_statix, :host), persistent: true)
    :ok = Application.put_env(:statix, :port, Keyword.get(@configuration_old_statix, :port), persistent: true)
    :ok = Application.put_env(:statix, :tags, nil, persistent: true)

    on_exit(fn ->
      # configuration is global state so we reset it to known values in case
      # it got fiddled before
      :ok = Application.put_env(@app, Tracer, @configuration_old, persistent: true)
      :ok = Application.put_env(@app, :spandex_datadog, @configuration_old_spandex_datadog, persistent: true)
      :ok = System.delete_env("HOSTNAME")
      :ok = System.delete_env("DD_DISABLED")
      :ok = System.delete_env("APP_ENV")
      :ok = System.delete_env("DD_PORT")
      :ok = System.delete_env("DD_HOSTNAME")
      :ok = System.delete_env("DD_APM_PORT")
      :ok = System.delete_env("BATCH_SIZE")
      :ok = System.delete_env("SYNC_THRESHOLD")
    end)

    :ok
  end

  test "if environment variables get applied in the configuration" do
    :ok = System.put_env("DD_DISABLED", "TRUE")
    :ok = System.put_env("APP_ENV", "YOLO")
    :ok = System.put_env("HOSTNAME", "this is my tracer test 3")
    :ok = SetTracer.init([])
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
    :ok = Application.put_env(@app, Tracer, @configuration_old, persistent: true)
    :ok = System.delete_env("DD_DISABLED")
    :ok = System.delete_env("APP_ENV")
    :ok = System.put_env("HOSTNAME", "this is my tracer test 3")
    :ok = SetTracer.init([])
    configuration = Application.get_env(@app, Tracer)
    sorted_configuration = Enum.sort(configuration)
    ^sorted_configuration = Enum.sort(@configuration_old)
  end

  test "if environment variables get applied in the statix configuration" do
    :ok = System.put_env("DD_HOSTNAME", "cluster")
    :ok = System.put_env("DD_PORT", "1919")
    :ok = System.put_env("HOSTNAME", "this is my tracer test 1")
    :ok = System.put_env("APP_ENV", "test 1")
    :ok = SetTracer.init(release: :test_case_1)
    configuration = Enum.sort(Application.get_all_env(:statix))
    host = configuration[:host]
    port = configuration[:port]
    "cluster" = host
    1919 = port

    assert configuration ==
             @configuration_old_statix
             |> Keyword.put(:host, "cluster")
             |> Keyword.put(:port, 1919)
             |> Keyword.put(:tags, ["application:test_case_1", "app_env:test 1", "hostname:this is my tracer test 1"])
             |> Enum.sort()
  end

  test "if default statix configuration is used when there's no environment variables" do
    :ok =
      Enum.each(@configuration_old_statix, fn {key, value} ->
        Application.put_env(:statix, key, value, persistent: true)
      end)

    :ok = System.delete_env("DD_HOSTNAME")
    :ok = System.delete_env("DD_PORT")
    :ok = System.put_env("HOSTNAME", "this is my tracer test 2")
    :ok = System.put_env("APP_ENV", "test 2")
    :ok = SetTracer.init(release: :test_case_2)
    configuration = Application.get_all_env(:statix)
    sorted_configuration = Enum.sort(configuration)
    expected_tags = ["application:test_case_2", "app_env:test 2", "hostname:this is my tracer test 2"]
    assert sorted_configuration == @configuration_old_statix |> Keyword.put(:tags, expected_tags) |> Enum.sort()
  end

  test "if environment variables get applied in the spandex_datadog configuration" do
    :ok = System.put_env("DD_HOSTNAME", "cluster")
    :ok = System.put_env("DD_APM_PORT", "1919")
    :ok = System.put_env("BATCH_SIZE", "7000")
    :ok = System.put_env("SYNC_THRESHOLD", "900")
    :ok = System.put_env("HOSTNAME", "this is my tracer test 4")
    :ok = SetTracer.init([])
    configuration = Enum.sort(Application.get_all_env(:spandex_datadog))
    host = configuration[:host]
    port = configuration[:port]
    batch_size = configuration[:batch_size]
    sync_threshold = configuration[:sync_threshold]
    "cluster" = host
    1919 = port
    7000 = batch_size
    900 = sync_threshold

    ^configuration =
      @configuration_old_spandex_datadog
      |> Keyword.put(:host, "cluster")
      |> Keyword.put(:port, 1919)
      |> Keyword.put(:batch_size, 7000)
      |> Keyword.put(:sync_threshold, 900)
      |> Enum.sort()
  end

  test "if default spandex_datadog configuration is used when there's no environment variables" do
    :ok =
      Enum.each(@configuration_old_spandex_datadog, fn {key, value} ->
        Application.put_env(:spandex_datadog, key, value, persistent: true)
      end)

    :ok = System.delete_env("DD_HOSTNAME")
    :ok = System.delete_env("DD_APM_PORT")
    :ok = System.delete_env("BATCH_SIZE")
    :ok = System.delete_env("SYNC_THRESHOLD")
    :ok = System.put_env("HOSTNAME", "this is my tracer test 5")
    :ok = SetTracer.init([])
    configuration = Application.get_all_env(:spandex_datadog)
    sorted_configuration = Enum.sort(configuration)

    ^sorted_configuration = Enum.sort(@configuration_old_spandex_datadog)
  end

  test "if exit is thrown when faulty configuration is used" do
    :ok = System.put_env("DD_DISABLED", "TRUEeee")
    catch_exit(SetTracer.init([]))
    :ok = System.delete_env("DD_DISABLED")
  end

  test "if environment variables get applied in the statix tags configuration" do
    :ok = System.put_env("HOSTNAME", "this is my tracer test")
    :ok = System.put_env("APP_ENV", "YOLO")
    :ok = SetTracer.init([])
    assert Enum.member?(Application.get_env(:statix, :tags), "hostname:this is my tracer test")
  end

  test "if exit is thrown when faulty configuration for hostname is used" do
    :ok = System.put_env("DD_DISABLED", "TRUE")
    :ok = System.put_env("APP_ENV", "YOLO")
    assert catch_exit(SetTracer.init([])) == "HOSTNAME is not set correctly."
    :ok = System.delete_env("DD_DISABLED")
  end
end
