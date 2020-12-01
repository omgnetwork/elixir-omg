# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.WatcherInfo.Fixtures do
  use ExUnitFixtures.FixtureModule

  use OMG.Eth.Fixtures
  use OMG.DB.Fixtures
  use OMG.Utils.LoggerExt
  use OMG.Fixtures

  alias Ecto.Adapters.SQL
  alias OMG.Crypto
  alias OMG.WatcherInfo
  alias OMG.WatcherInfo.DB

  @eth OMG.Eth.zero_address()

  deffixture in_beam_watcher(db_initialized, contract) do
    :ok = db_initialized
    _ = contract

    {:ok, started_apps} = Application.ensure_all_started(:omg_db)
    {:ok, started_watcher} = Application.ensure_all_started(:omg_watcher_info)
    {:ok, started_watcher_api} = Application.ensure_all_started(:omg_watcher_rpc)

    [] = DB.Repo.all(DB.Block)

    on_exit(fn ->
      Application.put_env(:omg_db, :path, nil)

      (started_apps ++ started_watcher ++ started_watcher_api)
      |> Enum.reverse()
      |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end)
  end

  deffixture web_endpoint do
    Application.ensure_all_started(:spandex_ecto)
    Application.ensure_all_started(:telemetry)

    :telemetry.attach(
      "spandex-query-tracer",
      [:omg, :watcher, :db, :repo, :query],
      &SpandexEcto.TelemetryAdapter.handle_event/4,
      nil
    )

    {:ok, pid} = ensure_web_started(OMG.WatcherRPC.Web.Endpoint, :start_link, [], 100)

    _ = Application.load(:omg_watcher_rpc)

    on_exit(fn ->
      wait_for_process(pid)
      :ok
    end)
  end

  @doc "run only database in sandbox and endpoint to make request"
  deffixture phoenix_ecto_sandbox(web_endpoint) do
    :ok = web_endpoint

    {:ok, pid} =
      Supervisor.start_link(
        [%{id: DB.Repo, start: {DB.Repo, :start_link, []}, type: :supervisor}],
        strategy: :one_for_one,
        name: WatcherInfo.Supervisor
      )

    :ok = SQL.Sandbox.checkout(DB.Repo)
    SQL.Sandbox.mode(DB.Repo, {:shared, self()})
    # setup and body test are performed in one process, `on_exit` is performed in another
    on_exit(fn ->
      wait_for_process(pid)
      :ok
    end)
  end

  deffixture initial_blocks(alice, bob, blocks_inserter, initial_deposits) do
    :ok = initial_deposits

    blocks = [
      {1000,
       [
         OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 300}]),
         OMG.TestHelper.create_recovered([{1000, 0, 0, bob}], @eth, [{alice, 100}, {bob, 200}])
       ]},
      {2000,
       [
         OMG.TestHelper.create_recovered([{1000, 1, 0, alice}], @eth, [{bob, 99}, {alice, 1}], <<1337::256>>)
       ]},
      {3000,
       [
         OMG.TestHelper.create_recovered([], @eth, [{alice, 150}]),
         OMG.TestHelper.create_recovered([{1000, 1, 1, bob}], @eth, [{bob, 150}, {alice, 50}])
       ]}
    ]

    blocks_inserter.(blocks)
  end

  deffixture initial_deposits(alice, bob, phoenix_ecto_sandbox) do
    :ok = phoenix_ecto_sandbox

    deposits = [
      %{
        root_chain_txhash: Crypto.hash(<<1000::256>>),
        log_index: 0,
        owner: alice.addr,
        currency: @eth,
        amount: 333,
        eth_height: 1,
        otype: 1,
        blknum: 1
      },
      %{
        root_chain_txhash: Crypto.hash(<<2000::256>>),
        log_index: 0,
        owner: bob.addr,
        currency: @eth,
        amount: 100,
        otype: 1,
        eth_height: 2,
        blknum: 2
      }
    ]

    # Initial data depending tests can reuse
    DB.EthEvent.insert_deposits!(deposits)
    :ok
  end

  deffixture blocks_inserter(phoenix_ecto_sandbox) do
    :ok = phoenix_ecto_sandbox

    fn blocks -> Enum.flat_map(blocks, &prepare_one_block/1) end
  end

  defp prepare_one_block({blknum, recovered_txs}) do
    mined_block = %{
      transactions: recovered_txs,
      blknum: blknum,
      blkhash: "##{blknum}",
      timestamp: 1_540_465_606,
      eth_height: 1
    }

    {:ok, pending_block} =
      DB.PendingBlock.insert(%{
        data: :erlang.term_to_binary(mined_block),
        blknum: blknum
      })

    {:ok, _} = DB.Block.insert_from_pending_block(pending_block)

    recovered_txs
    |> Enum.with_index()
    |> Enum.map(fn {recovered_tx, txindex} -> {blknum, txindex, recovered_tx.tx_hash, recovered_tx} end)
  end

  defp ensure_web_started(module, function, args, counter) do
    _ = Process.flag(:trap_exit, true)
    do_ensure_web_started(module, function, args, counter)
  end

  defp do_ensure_web_started(module, function, args, 0), do: apply(module, function, args)

  defp do_ensure_web_started(module, function, args, counter) do
    {:ok, _pid} = result = apply(module, function, args)
    result
  rescue
    e in MatchError ->
      %MatchError{
        term:
          {:error,
           {:shutdown,
            {:failed_to_start_child, {:ranch_listener_sup, OMG.WatcherRPC.Web.Endpoint.HTTP},
             {:shutdown,
              {:failed_to_start_child, :ranch_acceptors_sup,
               {:listen_error, OMG.WatcherRPC.Web.Endpoint.HTTP, :eaddrinuse}}}}}}
      } = e

      :ok = Process.sleep(5)
      ensure_web_started(module, function, args, counter - 1)
  end

  defp wait_for_process(pid, timeout \\ :infinity) when is_pid(pid) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, _, _} ->
        :ok
    after
      timeout ->
        throw({:timeouted_waiting_for, pid})
    end
  end
end
