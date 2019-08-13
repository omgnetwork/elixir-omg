# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.Status.ReleaseTasks.SetSentryTest do
  use ExUnit.Case, async: false
  alias OMG.Status.ReleaseTasks.SetSentry
  @app :sentry
  @configuration_old Application.get_all_env(@app)

  test "if environment variables get applied in the configuration" do
    :ok = System.put_env("SENTRY_DSN", "/dsn/dsn/dsn")
    :ok = System.put_env("APP_ENV", "YOLO")
    :ok = System.put_env("HOSTNAME", "server name")
    :ok = System.put_env("ETHEREUM_NETWORK", "RINKEBY")
    :ok = SetSentry.init([])
    configuration = Enum.sort(Application.get_all_env(@app))
    dsn = configuration[:dsn]
    app_env = configuration[:environment_name]
    app_env_included_environments = configuration[:included_environments]
    server_name = configuration[:server_name]
    tags = configuration[:tags]
    "/dsn/dsn/dsn" = dsn
    "YOLO" = app_env
    "YOLO" = hd(app_env_included_environments)
    "server name" = server_name

    :watcher = Map.get(tags, :application)
    "RINKEBY" = Map.get(tags, :eth_network)
    "geth" = Map.get(tags, :eth_node)

    ^configuration =
      @configuration_old
      |> Keyword.put(:dsn, "/dsn/dsn/dsn")
      |> Keyword.put(:environment_name, "YOLO")
      |> Keyword.put(:included_environments, ["YOLO"])
      |> Keyword.put(:server_name, "server name")
      |> Keyword.put(:tags, %{application: :watcher, eth_network: "RINKEBY", eth_node: "geth"})
      |> Enum.sort()
  end

  # test "if default configuration is used when there's no environment variables" do
  #   :ok = Application.put_env(@app, Tracer, @configuration_old, persistent: true)
  #   :ok = System.delete_env("DD_DISABLED")
  #   :ok = System.delete_env("APP_ENV")
  #   :ok = SetTracer.init([])
  #   configuration = Application.get_env(@app, Tracer)
  #   sorted_configuration = Enum.sort(configuration)
  #   ^sorted_configuration = Enum.sort(@configuration_old)
  # end

  # test "if environment variables get applied in the statix configuration" do
  #   :ok = System.put_env("DD_HOSTNAME", "cluster")
  #   :ok = System.put_env("DD_PORT", "1919")
  #   :ok = SetTracer.init([])
  #   configuration = Application.get_all_env(:statix)
  #   host = configuration[:host]
  #   port = configuration[:port]
  #   "cluster" = host
  #   1919 = port

  #   ^configuration =
  #     @configuration_old_statix
  #     |> Keyword.put(:host, "cluster")
  #     |> Keyword.put(:port, 1919)
  #     |> Enum.sort()
  # end

  # test "if default statix configuration is used when there's no environment variables" do
  #   :ok =
  #     Enum.each(@configuration_old_statix, fn {key, value} ->
  #       Application.put_env(:statix, key, value, persistent: true)
  #     end)

  #   :ok = System.delete_env("DD_HOSTNAME")
  #   :ok = System.delete_env("DD_PORT")
  #   :ok = SetTracer.init([])
  #   configuration = Application.get_all_env(:statix)
  #   sorted_configuration = Enum.sort(configuration)

  #   ^sorted_configuration = Enum.sort(@configuration_old_statix)
  # end

  # test "if environment variables get applied in the spandex_datadog configuration" do
  #   :ok = System.put_env("DD_HOSTNAME", "cluster")
  #   :ok = System.put_env("DD_PORT", "1919")
  #   :ok = System.put_env("BATCH_SIZE", "7000")
  #   :ok = System.put_env("SYNC_THRESHOLD", "900")
  #   :ok = SetTracer.init([])
  #   configuration = Enum.sort(Application.get_all_env(:spandex_datadog))
  #   host = configuration[:host]
  #   port = configuration[:port]
  #   batch_size = configuration[:batch_size]
  #   sync_threshold = configuration[:sync_threshold]
  #   "cluster" = host
  #   1919 = port
  #   7000 = batch_size
  #   900 = sync_threshold

  #   ^configuration =
  #     @configuration_old_spandex_datadog
  #     |> Keyword.put(:host, "cluster")
  #     |> Keyword.put(:port, 1919)
  #     |> Keyword.put(:batch_size, 7000)
  #     |> Keyword.put(:sync_threshold, 900)
  #     |> Enum.sort()
  # end

  # test "if default spandex_datadog configuration is used when there's no environment variables" do
  #   :ok =
  #     Enum.each(@configuration_old_spandex_datadog, fn {key, value} ->
  #       Application.put_env(:spandex_datadog, key, value, persistent: true)
  #     end)

  #   :ok = System.delete_env("DD_HOSTNAME")
  #   :ok = System.delete_env("DD_PORT")
  #   :ok = System.delete_env("BATCH_SIZE")
  #   :ok = System.delete_env("SYNC_THRESHOLD")
  #   :ok = SetTracer.init([])
  #   configuration = Application.get_all_env(:spandex_datadog)
  #   sorted_configuration = Enum.sort(configuration)

  #   ^sorted_configuration = Enum.sort(@configuration_old_spandex_datadog)
  # end

  # test "if exit is thrown when faulty configuration is used" do
  #   :ok = System.put_env("DD_DISABLED", "TRUEeee")

  #   try do
  #     :ok = SetTracer.init([])
  #   catch
  #     :exit, _ ->
  #       :ok = System.delete_env("DD_DISABLED")
  #   end
  # end
end
