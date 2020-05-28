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

defmodule OMG.Performance.SimplePerftest do
  @moduledoc """
  The simple performance tests runs the critical transaction processing chunk of the child chain.

  This allows to easily test the critical path of processing transactions, and profile it using `:fprof`.
  """
  use OMG.Utils.LoggerExt
  require OMG.Utxo

  alias OMG.Eth.Configuration
  alias OMG.TestHelper
  alias OMG.Utxo

  @eth OMG.Eth.zero_address()

  @doc """
  Runs test with `ntx_to_send` txs for each of the `nspenders` senders with given options.
  The test is run on a local limited child chain app instance, not doing any Ethereum connectivity-related activities.
  The child chain is setup and torn down as part of the test invocation.

  ## Usage

  From an `iex -S mix run --no-start` shell

  ```
  use OMG.Performance

  Performance.SimplePerftest.start(50, 16)
  ```

  The results are going to be waiting for you in a file within `destdir` and will be logged.

  Options:
    - :destdir - directory where the results will be put, relative to `pwd`, defaults to `"."`
    - :profile - if `true`, a `:fprof` will profile the test run, defaults to `false`
    - :block_every_ms - how often should the artificial block creation be triggered, defaults to `2000`
    - :randomized - whether the non-change outputs of the txs sent out will be random or equal to sender (if `false`),
      defaults to `true`

    **NOTE**:

    With `profile: :fprof` it will print a warning:
    ```
    Warning: {erlang, trace, 3} called in "<0.514.0>" - trace may become corrupt!
    ```
    It is caused by using `procs: :all` in options. So far we're not using `:erlang.trace/3` in our code,
    so it has been ignored. Otherwise it's easy to reproduce and report
    (github.com/erlang/otp and the JIRA it points you to).
  """
  @spec start(pos_integer(), pos_integer(), keyword()) :: :ok
  def start(ntx_to_send, nspenders, opts \\ []) do
    _ =
      Logger.info(
        "Number of spenders: #{inspect(nspenders)}, number of tx to send per spender: #{inspect(ntx_to_send)}."
      )

    defaults = [destdir: ".", profile: false, block_every_ms: 2000]
    opts = Keyword.merge(defaults, opts)

    {:ok, started_apps, simple_perftest_chain} = setup_simple_perftest(opts)

    spenders = create_spenders(nspenders)
    utxos = create_deposits(spenders, ntx_to_send)

    :ok = OMG.Performance.Runner.run(ntx_to_send, utxos, opts, opts[:profile])

    cleanup_simple_perftest(started_apps, simple_perftest_chain)
  end

  @spec setup_simple_perftest(keyword()) :: {:ok, list, pid}
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
      {OMG.State,
       [
         fee_claimer_address: Base.decode16!("DEAD000000000000000000000000000000000000"),
         child_block_interval: Configuration.child_block_interval(),
         metrics_collection_interval: 60_000
       ]},
      {OMG.ChildChain.FreshBlocks, []},
      {OMG.ChildChain.FeeServer, OMG.ChildChain.Configuration.fee_server_opts()},
      {OMG.Performance.BlockCreator, opts[:block_every_ms]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  @spec cleanup_simple_perftest(list(), pid) :: :ok
  defp cleanup_simple_perftest(started_apps, simple_perftest_chain) do
    :ok = Supervisor.stop(simple_perftest_chain)
    started_apps |> Enum.reverse() |> Enum.each(&Application.stop/1)

    :ok = Application.put_env(:omg_db, :path, nil)
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

  @spec create_deposits(list(TestHelper.entity()), pos_integer()) :: list(map())
  defp create_deposits(spenders, ntx_to_send) do
    spenders
    |> Enum.with_index(1)
    |> Enum.map(&create_deposit(&1, ntx_to_send * 2))
  end

  defp create_deposit({spender, index}, ntx_to_send) do
    {:ok, _} =
      OMG.State.deposit([
        %{
          # these two are irrelevant
          root_chain_txhash: <<0::256>>,
          eth_height: 1,
          log_index: 0,
          owner: spender.addr,
          currency: @eth,
          amount: ntx_to_send,
          blknum: index
        }
      ])

    utxo_pos = Utxo.position(index, 0, 0) |> Utxo.Position.encode()
    %{owner: spender, utxo_pos: utxo_pos, amount: ntx_to_send}
  end
end
