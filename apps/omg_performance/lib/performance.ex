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

  ## start_standard_exit_perftest runs test that fetches standard exit data from the Watcher
  ## standard_exit_perftest is run on testnet make sure you followed instruction in `README.md` and `get`, `omg_childchain` & `omg_watcher` are running.

  ```
  mix run --no-start -e 'OMG.Performance.start_standard_exit_perftest([%{ addr: <<192, 206, 18, ...>>, priv: <<246, 22, 164, ...>>}], 3, "0xbc5f ...")'
  ```

  ## Parameters passed are: 1. list of senders, 2. number of users that fetching exits in parallel, 3. contract address
  With default options, number of transactions sent to the network is 10 times the senders count per each sender
  Number of exiting utxo is total number of transactions, each exiting user ask for the same utxo set, but mixes the order.
  """

  use OMG.Utils.LoggerExt

  alias OMG.Crypto
  alias OMG.Performance.ByzantineEvents
  alias OMG.TestHelper
  alias OMG.Utxo
  alias Support.Integration.DepositHelper

  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()

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
        "PerfTest number of spenders: #{inspect(nspenders)}, number of tx to send per spender: #{inspect(ntx_to_send)}."
      )

    url =
      System.get_env("CHILD_CHAIN_URL") || Application.get_env(:omg_watcher, :child_chain_url, "http://localhost:9656")

    defaults = %{destdir: ".", profile: false, block_every_ms: 2000, child_chain_url: url}
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
          Crypto.address_t(),
          map()
        ) :: :ok
  def start_extended_perftest(ntx_to_send, spenders, contract_addr, opts \\ %{}) do
    _ =
      Logger.info(
        "PerfTest number of spenders: #{inspect(length(spenders))}, number of tx to send per spender: #{
          inspect(ntx_to_send)
        }."
      )

    url =
      System.get_env("CHILD_CHAIN_URL") || Application.get_env(:omg_watcher, :child_chain_url, "http://localhost:9656")

    defaults = %{
      destdir: ".",
      geth: System.get_env("ETHEREUM_RPC_URL") || "http://localhost:8545",
      child_chain_url: url
    }

    opts = Map.merge(defaults, opts)

    {:ok, started_apps} = setup_extended_perftest(opts, contract_addr)

    utxos = create_utxos_for_extended_perftest(spenders, ntx_to_send)

    run({ntx_to_send, utxos, opts, false})

    cleanup_extended_perftest(started_apps)
  end

  @doc """
  Starts with extended perftest to populate network with transactions.
  Then with a given `exit_users` start fetching exit data from Watcher.
  """
  @spec start_standard_exit_perftest(list(TestHelper.entity()), pos_integer(), Crypto.address_t(), map()) :: %{
          opts: map(),
          statistics: [ByzantineEvents.stats_t()]
        }
  def start_standard_exit_perftest(spenders, exiting_users, contract_addr, opts \\ %{}) do
    # in case number of txs to send wasn't set, provides defaults
    spenders_count = length(spenders)
    ntx_to_send = 10 * spenders_count

    opts =
      opts
      |> Map.put_new(:spenders_count, spenders_count)
      |> Map.put_new(:ntx_to_send, ntx_to_send)
      |> Map.put_new(:exits_per_user, ntx_to_send * spenders_count)

    :ok = start_extended_perftest(opts.ntx_to_send, spenders, contract_addr, opts)

    # wait before asking watcher about exit data
    ByzantineEvents.watcher_synchronize()

    _ =
      Logger.info(
        "Std exit perftest with #{spenders_count * ntx_to_send} txs in the network, Watcher synced, fetching #{
          opts.exits_per_user
        } exit data with #{exiting_users} users."
      )

    exit_positions = setup_standard_exit_perftest(opts)

    statistics = ByzantineEvents.start_dos_get_exits(exit_positions, exiting_users)

    %{opts: opts, statistics: statistics}
  end

  # Hackney is http-client httpoison's dependency.
  # We start omg_child_chain app that will will start omg_child_chain_rpc
  # (because of it's dependency when mix env == test).
  # We don't need :omg application so we stop it and clear all alarms it raised
  # (otherwise omg_child_chain_rpc gets notified of alarms and halts requests).
  # We also don't want all descendants of Monitoring process so we terminate it.

  @spec setup_simple_perftest(map()) :: {:ok, list, pid}
  defp setup_simple_perftest(opts) do
    {:ok, _} = Application.ensure_all_started(:briefly)
    {:ok, dbdir} = Briefly.create(directory: true, prefix: "rocksdb")
    Application.put_env(:omg_db, :path, dbdir, persistent: true)
    _ = Logger.info("Perftest rocksdb path: #{inspect(dbdir)}")

    :ok = OMG.DB.init()

    started_apps = ensure_all_started([:omg_db, :cowboy, :hackney, :omg_bus])
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

  @spec setup_extended_perftest(map(), Crypto.address_t()) :: {:ok, list}
  defp setup_extended_perftest(opts, contract_addr) do
    {:ok, _} = Application.ensure_all_started(:ethereumex)

    # hackney is http-client httpoison's dependency
    started_apps = ensure_all_started([:hackney])

    Application.put_env(:ethereumex, :request_timeout, :infinity)
    Application.put_env(:ethereumex, :http_options, recv_timeout: :infinity)
    Application.put_env(:ethereumex, :url, opts[:geth])

    Application.put_env(:omg_eth, :contract_addr, OMG.Eth.RootChain.contract_map_to_hex(contract_addr))

    {:ok, started_apps}
  end

  @spec cleanup_simple_perftest(list(), pid) :: :ok
  defp cleanup_simple_perftest(started_apps, simple_perftest_chain) do
    :ok = Supervisor.stop(simple_perftest_chain)
    started_apps |> Enum.reverse() |> Enum.each(&Application.stop/1)

    _ = Application.stop(:briefly)

    Application.put_env(:omg_db, :path, nil)
    :ok
  end

  @spec cleanup_extended_perftest([]) :: :ok
  defp cleanup_extended_perftest(started_apps) do
    started_apps |> Enum.reverse() |> Enum.each(&Application.stop/1)
    :ok
  end

  @spec setup_standard_exit_perftest(map()) :: map()
  defp setup_standard_exit_perftest(opts) do
    exit_for = Map.get(opts, :exit_for)

    utxos =
      case exit_for do
        %{addr: addr} ->
          addr
          |> ByzantineEvents.get_exitable_utxos()
          |> Enum.map(& &1.utxo_pos)
          |> Enum.shuffle()
          |> Enum.take(opts.exits_per_user)

        nil ->
          utxo_positions_stream = ByzantineEvents.Generators.stream_utxo_positions()
          Enum.take(utxo_positions_stream, opts.exits_per_user)
      end

    _ = Logger.debug("Get #{length(utxos)} utxos for exit, for user: #{Map.get(exit_for || %{}, :addr, "<no user>")}")
    utxos
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
      {:ok, db_updates} =
        OMG.State.deposit([%{owner: spender.addr, currency: @eth, amount: ntx_to_send, blknum: index}])

      :ok = OMG.DB.multi_update(db_updates)

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
