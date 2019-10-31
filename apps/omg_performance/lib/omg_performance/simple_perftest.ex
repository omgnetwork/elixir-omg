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

defmodule OMG.Performance.SimplePerftest do
  use OMG.Utils.LoggerExt

  alias OMG.TestHelper
  alias OMG.Utxo

  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @doc """
  Runs test with {ntx_to_send} tx for each {nspenders} senders with given options.

  Default options:
  ```
  %{
    destdir: ".", # directory where the results will be put
    profile: false,
    block_every_ms: 2000 # how often do you want the tester to force a block being formed
  }
  ```
  """
  @spec start(pos_integer(), pos_integer(), map()) :: :ok
  def start(ntx_to_send, nspenders, opts \\ %{}) do
    _ =
      Logger.info(
        "Number of spenders: #{inspect(nspenders)}, number of tx to send per spender: #{inspect(ntx_to_send)}."
      )

    defaults = %{destdir: ".", profile: false, block_every_ms: 2000}
    opts = Map.merge(defaults, opts)

    {:ok, started_apps, simple_perftest_chain} = setup_simple_perftest(opts)

    spenders = create_spenders(nspenders)
    utxos = create_deposits(spenders, ntx_to_send)

    {:ok, data} = OMG.Performance.Runner.run({ntx_to_send, utxos, opts, opts[:profile]})
    _ = Logger.info("#{inspect(data)}")

    cleanup_simple_perftest(started_apps, simple_perftest_chain)
  end

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

  @spec create_deposits(list(TestHelper.entity()), pos_integer()) :: list()
  defp create_deposits(spenders, ntx_to_send) do
    spenders
    |> Enum.with_index(1)
    |> Enum.map(fn {spender, index} ->
      {:ok, _} = OMG.State.deposit([%{owner: spender.addr, currency: @eth, amount: ntx_to_send, blknum: index}])

      utxo_pos = Utxo.position(index, 0, 0) |> Utxo.Position.encode()
      %{owner: spender, utxo_pos: utxo_pos, amount: ntx_to_send}
    end)
  end
end
