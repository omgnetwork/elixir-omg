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

defmodule LoadTest.Performance do
  @moduledoc """
  OMG network performance tests. Provides general setup and utilities to do the perf tests.
  """

  defmacro __using__(_opt) do
    quote do
      alias LoadTest.Performance
      alias LoadTest.Performance.ByzantineEvents
      alias LoadTest.Performance.ExtendedPerftest
      alias LoadTest.Performance.Generators

      import Performance, only: [timeit: 1]
      require Performance
      require Logger

      :ok
    end
  end

  @doc """
  Sets up the `OMG.Performance` machinery to a required config. Uses some default values, overridable via:
    - `opts`
    - system env (some entries)
    - `config.exs`
  in that order of preference. The configuration chosen is put into `Application`'s environment

  Options:
    - :ethereum_rpc_url - URL of the Ethereum node's RPC, default `http://localhost:8545`
    - :child_chain_url - URL of the Child Chain server's RPC, default `http://localhost:9656`
    - :watcher_url - URL of the Watcher's RPC, default `http://localhost:7434`
    - :contract_addr - a map with the root chain contract addresses

  If you're testing against a local child chain/watcher instances, consider setting the following configuration:
  ```
  config :omg,
    deposit_finality_margin: 1
  config :omg_watcher,
    exit_finality_margin: 1
  ```
  in order to prevent the apps from waiting for unnecessary confirmations

  """
  def init(opts \\ []) do
    {:ok, _} = Application.ensure_all_started(:briefly)
    {:ok, _} = Application.ensure_all_started(:ethereumex)
    {:ok, _} = Application.ensure_all_started(:hackney)
    {:ok, _} = Application.ensure_all_started(:cowboy)

    ethereum_rpc_url =
      System.get_env("ETHEREUM_RPC_URL") || Application.get_env(:ethereumex, :url, "http://localhost:8545")

    child_chain_url =
      System.get_env("CHILD_CHAIN_URL") || Application.get_env(:omg_watcher, :child_chain_url, "http://localhost:9656")

    watcher_url =
      System.get_env("WATCHER_URL") || Application.get_env(:omg_performance, :watcher_url, "http://localhost:7434")

    defaults = [
      ethereum_rpc_url: ethereum_rpc_url,
      child_chain_url: child_chain_url,
      watcher_url: watcher_url,
      contract_addr: nil
    ]

    opts = Keyword.merge(defaults, opts)

    :ok = Application.put_env(:ethereumex, :request_timeout, :infinity)
    :ok = Application.put_env(:ethereumex, :http_options, recv_timeout: :infinity)
    :ok = Application.put_env(:ethereumex, :url, opts[:ethereum_rpc_url])
    :ok = Application.put_env(:omg_watcher, :child_chain_url, opts[:child_chain_url])
    :ok = Application.put_env(:omg_performance, :watcher_url, opts[:watcher_url])

    :ok
  end

  @doc """
  Utility macro which causes the expression given to be timed, the timing logged (`info`) and the original result of the
  call to be returned

  ## Examples

    iex> use LoadTest.Performance
    iex> timeit 1+2
    3
  """
  defmacro timeit(call) do
    quote do
      {duration, result} = :timer.tc(fn -> unquote(call) end)
      duration_s = duration / 1_000_000
      _ = Logger.info("Lasted #{inspect(duration_s)} seconds")
      result
    end
  end
end
