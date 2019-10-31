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

defmodule OMG.Performance do
  @moduledoc """
  OMG network child chain server performance test entrypoint. Setup and runs performance tests.

  # Usage

  See functions in this module for options available

  ## start_simple_perftest runs test with 5 transactions for each 3 senders and default options.

  ```
  mix run --no-start -e 'OMG.Performance.start_simple_perftest(5, 3)'
  ```

  ## start_extended_perftest runs test with 100 transactions for one specified account and default options.
  ## extended test is run on testnet make sure you followed instruction in `README.md` and both `geth` and `omg_child_chain` are running

  ```
  mix run --no-start -e 'OMG.Performance.start_extended_perftest(100, [%{ addr: <<192, 206, 18, ...>>, priv: <<246, 22, 164, ...>>}], "0xbc5f ...")'
  ```

  ## Parameters passed are: 1. number of transaction each sender will send, 2. list of senders (see: TestHelper.generate_entity()) and 3. `contract` address

  # Note:

  `:fprof` will print a warning:
  ```
  Warning: {erlang, trace, 3} called in "<0.514.0>" - trace may become corrupt!
  ```
  It is caused by using `procs: :all` in options. So far we're not using `:erlang.trace/3` in our code,
  so it has been ignored. Otherwise it's easy to reproduce and report if anyone has the nerve
  (github.com/erlang/otp and the JIRA it points you to).

  # FIXME this function was removed, re-edit the docs here

  ## start_standard_exit_perftest runs test that fetches standard exit data from the Watcher
  ## standard_exit_perftest is run on testnet make sure you followed instruction in `README.md` and `geth`,
  ## `omg_childchain` & `omg_watcher` are running.

  ```
  mix run --no-start -e 'OMG.Performance.start_standard_exit_perftest([%{ addr: <<192, 206, 18, ...>>, priv: <<246, 22, 164, ...>>}], 3, "0xbc5f ...")'
  ```

  ## Parameters passed are: 1. list of senders, 2. number of users that fetching exits in parallel, 3. contract address
  With default options, number of transactions sent to the network is 10 times the senders count per each sender
  Number of exiting utxo is total number of transactions, each exiting user ask for the same utxo set, but mixes the order.
  """

  use OMG.Utils.LoggerExt

  alias OMG.Crypto
  alias OMG.TestHelper
  alias OMG.Utxo
  alias Support.Integration.DepositHelper

  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  # FIXME docs
  # FIXME map to keyword for opts everywhere
  def init(opts \\ %{}) do
    {:ok, _} = Application.ensure_all_started(:briefly)
    {:ok, _} = Application.ensure_all_started(:ethereumex)
    {:ok, _} = Application.ensure_all_started(:hackney)
    {:ok, _} = Application.ensure_all_started(:cowboy)

    child_chain_url =
      System.get_env("CHILD_CHAIN_URL") || Application.get_env(:omg_watcher, :child_chain_url, "http://localhost:9656")

    ethereum_rpc_url =
      System.get_env("ETHEREUM_RPC_URL") || Application.get_env(:ethereumex, :url, "http://localhost:8545")

    defaults = %{
      ethereum_rpc_url: ethereum_rpc_url,
      child_chain_url: child_chain_url,
      contract_addr: nil
    }

    opts = Map.merge(defaults, opts)

    :ok = Application.put_env(:ethereumex, :request_timeout, :infinity)
    :ok = Application.put_env(:ethereumex, :http_options, recv_timeout: :infinity)
    :ok = Application.put_env(:ethereumex, :url, opts[:ethereum_rpc_url])

    :ok =
      if opts[:contract_addr],
        do: Application.put_env(:omg_eth, :contract_addr, OMG.Eth.RootChain.contract_map_to_hex(opts[:contract_addr])),
        else: :ok

    :ok = Application.put_env(:omg_watcher, :child_chain_url, opts[:child_chain_url])

    :ok
  end

  @doc """
  start_simple_perf runs test with {ntx_to_send} tx for each {nspenders} senders with given options.

  Default options:
  ```
  %{
    destdir: ".", # directory where the results will be put
    profile: false,
    block_every_ms: 2000 # how often do you want the tester to force a block being formed
  }
  ```
  """
  @spec start_simple_perftest(pos_integer(), pos_integer(), map()) :: :ok
  def start_simple_perftest(ntx_to_send, nspenders, opts \\ %{}) do
    _ =
      Logger.info(
        "Number of spenders: #{inspect(nspenders)}, number of tx to send per spender: #{inspect(ntx_to_send)}."
      )

    defaults = %{destdir: ".", profile: false, block_every_ms: 2000}
    opts = Map.merge(defaults, opts)

    {:ok, started_apps, simple_perftest_chain} = setup_simple_perftest(opts)

    spenders = create_spenders(nspenders)
    utxos = create_utxos_for_simple_perftest(spenders, ntx_to_send)

    run({ntx_to_send, utxos, opts, opts[:profile]})

    cleanup_simple_perftest(started_apps, simple_perftest_chain)
  end

  @doc """
  Runs test with {ntx_to_send} transactions for each {spenders}.
  Initial deposits for each account will be made on passed {contract_addr}.

  Default options:
  ```
  %{
    destdir: ".", # directory where the results will be put
    geth: System.get_env("ETHEREUM_RPC_URL"),
    child_chain: "http://localhost:9656"
  }
  ```
  """
  @spec start_extended_perftest(
          pos_integer(),
          list(TestHelper.entity()),
          map()
        ) :: :ok
  def start_extended_perftest(ntx_to_send, spenders, opts \\ %{}) do
    _ =
      Logger.info(
        "Number of spenders: #{inspect(length(spenders))}, number of tx to send per spender: #{inspect(ntx_to_send)}" <>
          ", #{inspect(length(spenders) * length(ntx_to_send))} txs in total"
      )

    defaults = %{destdir: "."}

    opts = Map.merge(defaults, opts)

    utxos = create_utxos_for_extended_perftest(spenders, ntx_to_send)

    # FIXME: the way the profile option is handled is super messy - clean this
    run({ntx_to_send, utxos, opts, false})
  end

  # Hackney is http-client httpoison's dependency.
  # We start omg_child_chain app that will will start omg_child_chain_rpc
  # (because of it's dependency when mix env == test).
  # We don't need :omg application so we stop it and clear all alarms it raised
  # (otherwise omg_child_chain_rpc gets notified of alarms and halts requests).
  # We also don't want all descendants of Monitoring process so we terminate it.

  @spec setup_simple_perftest(map()) :: {:ok, list, pid}
  defp setup_simple_perftest(opts) do
    {:ok, dbdir} = Briefly.create(directory: true, prefix: "perftest_db")
    Application.put_env(:omg_db, :path, dbdir, persistent: true)
    _ = Logger.info("Perftest rocksdb path: #{inspect(dbdir)}")

    :ok = OMG.DB.init()

    started_apps = ensure_all_started([:omg_db, :omg_bus])
    {:ok, simple_perftest_chain} = start_simple_perftest_chain(opts)

    {:ok, started_apps, simple_perftest_chain}
  end

  # Selects and starts just necessary components to run the tests.
  # We don't want to start the entire `:omg_child_chain` supervision tree because
  # we don't want to start services related to root chain tracking (the root chain contract doesn't exist).
  # Instead, we start the artificial `BlockCreator`
  defp start_simple_perftest_chain(opts) do
    children = [
      {OMG.ChildChainRPC.Web.Endpoint, []},
      {OMG.State, []},
      {OMG.ChildChain.FreshBlocks, []},
      {OMG.ChildChain.FeeServer, []},
      {OMG.Performance.BlockCreator, opts[:block_every_ms]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  @spec cleanup_simple_perftest(list(), pid) :: :ok
  defp cleanup_simple_perftest(started_apps, simple_perftest_chain) do
    :ok = Supervisor.stop(simple_perftest_chain)
    started_apps |> Enum.reverse() |> Enum.each(&Application.stop/1)

    # FIXME at the very end, try removing all the many ensure_all_starteds on briefly. WTF
    # _ = Application.stop(:briefly)

    Application.put_env(:omg_db, :path, nil)
    :ok
  end

  @spec run({pos_integer(), list(), %{atom => any()}, boolean()}) :: :ok
  defp run(args) do
    {:ok, data} = OMG.Performance.Runner.run(args)
    _ = Logger.info("#{inspect(data)}")
    :ok
  end

  # We're not basing on mix to start all neccessary test's components.
  defp ensure_all_started(app_list) do
    Enum.reduce(app_list, [], fn app, list ->
      {:ok, started_apps} = Application.ensure_all_started(app)
      list ++ started_apps
    end)
  end

  @spec create_spenders(pos_integer()) :: list(TestHelper.entity())
  defp create_spenders(nspenders) do
    1..nspenders
    |> Enum.map(fn _nspender -> TestHelper.generate_entity() end)
  end

  @spec create_utxos_for_simple_perftest(list(TestHelper.entity()), pos_integer()) :: list()
  defp create_utxos_for_simple_perftest(spenders, ntx_to_send) do
    spenders
    |> Enum.with_index(1)
    |> Enum.map(fn {spender, index} ->
      {:ok, _} = OMG.State.deposit([%{owner: spender.addr, currency: @eth, amount: ntx_to_send, blknum: index}])

      utxo_pos = Utxo.position(index, 0, 0) |> Utxo.Position.encode()
      %{owner: spender, utxo_pos: utxo_pos, amount: ntx_to_send}
    end)
  end

  @spec create_utxos_for_extended_perftest(list(TestHelper.entity()), pos_integer()) :: list()
  defp create_utxos_for_extended_perftest(spenders, ntx_to_send) do
    make_deposits(10 * ntx_to_send, spenders)
    |> Enum.map(fn {:ok, owner, blknum, amount} ->
      utxo_pos = Utxo.position(blknum, 0, 0) |> Utxo.Position.encode()
      %{owner: owner, utxo_pos: utxo_pos, amount: amount}
    end)
  end

  defp make_deposits(value, accounts) do
    deposit = fn account ->
      deposit_blknum = DepositHelper.deposit_to_child_chain(account.addr, value)

      {:ok, account, deposit_blknum, value}
    end

    accounts
    |> Enum.map(&Task.async(fn -> deposit.(&1) end))
    |> Enum.map(fn task -> Task.await(task, :infinity) end)
  end
end
