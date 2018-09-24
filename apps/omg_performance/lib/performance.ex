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

  # Examples

  ## start_simple_perftest runs test with 5 transactions for each 3 senders and default options.
    ```> mix run --no-start -e 'OMG.Performance.start_simple_perftest(5, 3)'```

  ## start_extended_perftest runs test with 100 transactions for one specified account and default options.
    ```> mix run --no-start -e 'OMG.Performance.start_extended_perftest(100, [%{ addr: <<192, 206, 18, ...>>, priv: <<246, 22, 164, ...>>}], "0xbc5f ...")'```

  # Note:

  `:fprof` will print a warning:
  ```
  Warning: {erlang, trace, 3} called in "<0.514.0>" - trace may become corrupt!
  ```
  It is caused by using `procs: :all` in options. So far we're not using `:erlang.trace/3` in our code,
  so it has been ignored. Otherwise it's easy to reproduce and report if anyone has the nerve
  (github.com/erlang/otp and the JIRA it points you to).
  """

  use OMG.API.LoggerExt

  alias OMG.API.Crypto
  alias OMG.API.TestHelper
  alias OMG.API.Utxo

  require Utxo

  import Supervisor.Spec

  @eth Crypto.zero_address()

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
      Logger.info(fn ->
        "PerfTest number of spenders: #{inspect(nspenders)}, number of tx to send per spender: #{inspect(ntx_to_send)}."
      end)

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
    geth: "http://localhost:8545",
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
      Logger.info(fn ->
        "PerfTest number of spenders: #{inspect(length(spenders))}, number of tx to send per spender: #{
          inspect(ntx_to_send)
        }."
      end)

    defaults = %{destdir: ".", geth: "http://localhost:8545", child_chain: "http://localhost:9656"}
    opts = Map.merge(defaults, opts)

    {:ok, started_apps} = setup_extended_perftest(opts, contract_addr)

    utxos = create_utxos_for_extended_perftest(spenders, ntx_to_send)

    Process.sleep(20_000)

    run({ntx_to_send, utxos, opts, false})

    cleanup_extended_perftest(started_apps)
  end

  @spec setup_simple_perftest(map()) :: {:ok, list, pid}
  defp setup_simple_perftest(opts) do
    {:ok, _} = Application.ensure_all_started(:briefly)
    {:ok, dbdir} = Briefly.create(directory: true, prefix: "leveldb")
    Application.put_env(:omg_db, :leveldb_path, dbdir, persistent: true)
    _ = Logger.info(fn -> "Perftest leveldb path: #{inspect(dbdir)}" end)

    :ok = OMG.DB.init()

    started_apps = ensure_all_started([:omg_db, :cowboy, :hackney])

    omg_port = Application.get_env(:omg_jsonrpc, :omg_api_rpc_port)

    # select just neccessary components to run the tests
    children = [
      supervisor(Phoenix.PubSub.PG2, [:eventer, []]),
      {OMG.API.State, []},
      {OMG.API.FreshBlocks, []},
      {OMG.API.FeeChecker, []},
      JSONRPC2.Servers.HTTP.child_spec(:http, OMG.JSONRPC.Server.Handler, port: omg_port)
    ]

    {:ok, api_children_supervisor} = Supervisor.start_link(children, strategy: :one_for_one)

    _ = OMG.Performance.BlockCreator.start_link(opts[:block_every_ms])

    {:ok, started_apps, api_children_supervisor}
  end

  @spec setup_extended_perftest(map(), Crypto.address_t()) :: {:ok, list}
  defp setup_extended_perftest(opts, contract_addr) do
    {:ok, _} = Application.ensure_all_started(:ethereumex)

    started_apps = ensure_all_started([:jsonrpc2])

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
    _ = Logger.info(fn -> "#{inspect(data)}" end)
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
      :ok = OMG.API.State.deposit([%{owner: spender.addr, currency: @eth, amount: ntx_to_send, blknum: index}])

      utxo_pos = Utxo.position(index, 0, 0) |> Utxo.Position.encode()
      %{owner: spender, utxo_pos: utxo_pos, amount: ntx_to_send}
    end)
  end

  @spec create_utxos_for_extended_perftest(list(TestHelper.entity()), pos_integer()) :: list()
  defp create_utxos_for_extended_perftest(spenders, ntx_to_send) do
    OMG.Eth.DevHelpers.make_deposits(10 * ntx_to_send, spenders)
    |> Enum.map(fn {:ok, owner, blknum, amount} ->
      utxo_pos = Utxo.position(blknum, 0, 0) |> Utxo.Position.encode()
      %{owner: owner, utxo_pos: utxo_pos, amount: amount}
    end)
  end
end
