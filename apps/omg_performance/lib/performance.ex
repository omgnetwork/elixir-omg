# Copyright 2018 OmiseGO Pte Ltd
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

  Always `cd apps/omg_performance` before running performance tests

  ## start_simple_perftest runs test with 5 transactions for each 3 senders and default options.
    ```> mix run -e 'OMG.Performance.start_simple_perftest(5, 3)'```

  ## start_extended_perftest runs test with 100 transactions for one specified account and default options.
  ## extended test is run on testnet make sure you followed instruction in `README.md` and both `geth` and `omg_api` are running
    ```> mix run -e 'OMG.Performance.start_extended_perftest(100, [%{ addr: <<192, 206, 18, ...>>, priv: <<246, 22, 164, ...>>}], "0xbc5f ...")'```
  ## Parameters passed are:  1. number of transaction each sender will send, 2. list of senders (see: TestHelper.generate_entity()) and 3. `contract` address

  # Note:

  `:fprof` will print a warning:
  ```
  Warning: {erlang, trace, 3} called in "<0.514.0>" - trace may become corrupt!
  ```
  It is caused by using `procs: :all` in options. So far we're not using `:erlang.trace/3` in our code,
  so it has been ignored. Otherwise it's easy to reproduce and report if anyone has the nerve
  (github.com/erlang/otp and the JIRA it points you to).
  """

  use OMG.LoggerExt

  alias OMG.Crypto
  alias OMG.Integration.DepositHelper
  alias OMG.TestHelper
  alias OMG.Utxo

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

    DeferredConfig.populate(:omg_rpc)

    defaults = %{destdir: ".", profile: false, block_every_ms: 2000}
    opts = Map.merge(defaults, opts)

    {:ok, started_apps, api_children_supervisor} = setup_simple_perftest(opts)

    spenders = create_spenders(nspenders)
    utxos = create_utxos_for_simple_perftest(spenders, ntx_to_send)

    run({ntx_to_send, utxos, opts, opts[:profile]})

    cleanup_simple_perftest(started_apps, api_children_supervisor)
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

    DeferredConfig.populate(:omg_rpc)

    url =
      Application.get_env(:omg_rpc, OMG.RPC.Client, "http://localhost:9656")
      |> case do
        nil -> nil
        opts -> Keyword.get(opts, :child_chain_url)
      end

    defaults = %{destdir: ".", geth: System.get_env("ETHEREUM_RPC_URL") || "http://localhost:8545", child_chain: url}
    opts = Map.merge(defaults, opts)

    {:ok, started_apps} = setup_extended_perftest(opts, contract_addr)

    utxos = create_utxos_for_extended_perftest(spenders, ntx_to_send)

    run({ntx_to_send, utxos, opts, false})

    cleanup_extended_perftest(started_apps)
  end

  @spec setup_simple_perftest(map()) :: {:ok, list, pid}
  defp setup_simple_perftest(opts) do
    {:ok, _} = Application.ensure_all_started(:briefly)
    {:ok, dbdir} = Briefly.create(directory: true, prefix: "leveldb")
    Application.put_env(:omg_db, :leveldb_path, dbdir, persistent: true)
    _ = Logger.info("Perftest leveldb path: #{inspect(dbdir)}")

    :ok = OMG.DB.init()

    # hackney is http-client httpoison's dependency
    started_apps = ensure_all_started([:omg_db, :cowboy, :hackney])

    # select just necessary components to run the tests
    children = [
      %{
        id: Phoenix.PubSub.PG2,
        start: {Phoenix.PubSub.PG2, :start_link, [:eventer, []]},
        type: :supervisor
      },
      {OMG.State, []},
      {OMG.API.FreshBlocks, []},
      {OMG.API.FeeServer, []},
      {OMG.RPC.Web.Endpoint, []}
    ]

    {:ok, api_children_supervisor} = Supervisor.start_link(children, strategy: :one_for_one)

    _ = OMG.Performance.BlockCreator.start_link(opts[:block_every_ms])

    {:ok, started_apps, api_children_supervisor}
  end

  @spec setup_extended_perftest(map(), Crypto.address_t()) :: {:ok, list}
  defp setup_extended_perftest(opts, contract_addr) do
    {:ok, _} = Application.ensure_all_started(:ethereumex)

    # hackney is http-client httpoison's dependency
    started_apps = ensure_all_started([:hackney])

    Application.put_env(:ethereumex, :request_timeout, :infinity)
    Application.put_env(:ethereumex, :http_options, recv_timeout: :infinity)
    Application.put_env(:ethereumex, :url, opts[:geth])

    {:ok, contract_addr_enc} = Crypto.encode_address(contract_addr)
    Application.put_env(:omg_eth, :contract_addr, contract_addr_enc)

    {:ok, started_apps}
  end

  @spec cleanup_simple_perftest([], pid) :: :ok
  defp cleanup_simple_perftest(started_apps, api_children_supervisor) do
    :ok = Supervisor.stop(api_children_supervisor)

    started_apps |> Enum.reverse() |> Enum.each(&Application.stop/1)

    _ = Application.stop(:briefly)

    Application.put_env(:omg_db, :leveldb_path, nil)
    :ok
  end

  @spec cleanup_extended_perftest([]) :: :ok
  defp cleanup_extended_perftest(started_apps) do
    started_apps |> Enum.reverse() |> Enum.each(&Application.stop/1)
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
    app_list
    |> Enum.reduce([], fn app, list ->
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
