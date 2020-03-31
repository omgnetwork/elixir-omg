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

defmodule OMG.Status.ReleaseTasks.SetSentryTest do
  use ExUnit.Case, async: false
  alias OMG.Status.ReleaseTasks.SetSentry

  @app :sentry
  @configuration_old Application.get_all_env(@app)

  setup_all do
    on_exit(fn ->
      :ok =
        Enum.each(@configuration_old, fn {key, value} -> Application.put_env(@app, key, value, persistent: true) end)
    end)

    :ok
  end

  setup do
    on_exit(fn ->
      :ok = System.delete_env("SENTRY_DSN")
      :ok = System.delete_env("APP_ENV")
      :ok = System.delete_env("HOSTNAME")
      :ok = System.delete_env("ETHEREUM_NETWORK")
      :ok = System.delete_env("ETH_NODE")

      :ok =
        Enum.each(@configuration_old, fn {key, value} -> Application.put_env(@app, key, value, persistent: true) end)
    end)

    :ok
  end

  test "if environment variables get applied in the configuration" do
    :ok = System.put_env("SENTRY_DSN", "/dsn/dsn/dsn")
    :ok = System.put_env("APP_ENV", "YOLO")
    :ok = System.put_env("HOSTNAME", "server name")
    :ok = System.put_env("ETHEREUM_NETWORK", "RINKEBY")
    :ok = SetSentry.load([],release: :watcher, current_version: "current_version")
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
    :geth = Map.get(tags, :eth_node)

    assert configuration ==
             @configuration_old
             |> Keyword.put(:dsn, "/dsn/dsn/dsn")
             |> Keyword.put(:environment_name, "YOLO")
             |> Keyword.put(:included_environments, ["YOLO"])
             |> Keyword.put(:server_name, "server name")
             |> Keyword.put(:tags, %{
               application: :watcher,
               eth_network: "RINKEBY",
               eth_node: :geth,
               app_env: "YOLO",
               current_version: "vsn-current_version",
               hostname: "server name"
             })
             |> Enum.sort()
  end

  test "if sentry is disabled if there's no SENTRY DSN env var set" do
    :ok = SetSentry.load([],release: :child_chain, current_version: "current_version")
    configuration = Enum.sort(Application.get_all_env(@app))
    dsn = configuration[:dsn]
    app_env = configuration[:environment_name]
    app_env_included_environments = configuration[:included_environments]
    server_name = configuration[:server_name]
    tags = configuration[:tags]
    nil = dsn
    nil = app_env
    [] = app_env_included_environments
    nil = server_name

    nil = Map.get(tags, :application)
    nil = Map.get(tags, :eth_network)
    :geth = Map.get(tags, :eth_node)

    ^configuration =
      @configuration_old
      |> Keyword.put(:dsn, nil)
      |> Keyword.put(:environment_name, nil)
      |> Keyword.put(:included_environments, [])
      |> Keyword.put(:server_name, nil)
      |> Keyword.put(:tags, %{application: nil, eth_network: nil, eth_node: :geth})
      |> Enum.sort()
  end

  test "if faulty eth node exits" do
    :ok = System.put_env("ETH_NODE", "random random random")
    :ok = System.put_env("SENTRY_DSN", "/dsn/dsn/dsn")

    try do
      SetSentry.load([],release: :child_chain, current_version: "current_version")
    catch
      :exit, _reason ->
        :ok
    end
  end
end
