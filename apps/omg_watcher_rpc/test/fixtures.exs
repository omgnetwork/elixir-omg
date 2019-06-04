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

# unfortunately something is wrong with the fixtures loading in `test_helper.exs` and the following needs to be done
Code.require_file("#{__DIR__}/../../omg_child_chain/test/omg_child_chain/integration/fixtures.exs")

defmodule OMG.WatcherRPC.Fixtures do
  use ExUnitFixtures.FixtureModule

  use OMG.Eth.Fixtures
  use OMG.DB.Fixtures
  use OMG.ChildChain.Integration.Fixtures
  use OMG.Utils.LoggerExt

  alias Ecto.Adapters.SQL
  alias OMG.Watcher
  alias OMG.Watcher.DB
  alias Watcher.TestHelper

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  deffixture blocks_inserter(phoenix_ecto_sandbox) do
    :ok = phoenix_ecto_sandbox

    fn blocks -> blocks |> Enum.flat_map(&prepare_one_block/1) end
  end

  deffixture initial_blocks(alice, bob, blocks_inserter, initial_deposits) do
    :ok = initial_deposits

    [
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
    |> blocks_inserter.()
  end

  deffixture initial_deposits(alice, bob, phoenix_ecto_sandbox) do
    :ok = phoenix_ecto_sandbox

    deposits = [
      %{owner: alice.addr, currency: @eth, amount: 333, blknum: 1},
      %{owner: bob.addr, currency: @eth, amount: 100, blknum: 2}
    ]

    # Initial data depending tests can reuse
    DB.EthEvent.insert_deposits!(deposits)
    :ok
  end

  @doc "run only database in sandbox and endpoint to make request"
  deffixture phoenix_ecto_sandbox do
    {:ok, pid} =
      Supervisor.start_link(
        [
          %{id: DB.Repo, start: {DB.Repo, :start_link, []}, type: :supervisor},
          %{id: OMG.WatcherRPC.Web.Endpoint, start: {OMG.WatcherRPC.Web.Endpoint, :start_link, []}, type: :supervisor}
        ],
        strategy: :one_for_one,
        name: Watcher.Supervisor
      )

    :ok = SQL.Sandbox.checkout(DB.Repo)
    # setup and body test are performed in one process, `on_exit` is performed in another
    on_exit(fn ->
      TestHelper.wait_for_process(pid)
      :ok
    end)
  end

  defp prepare_one_block({blknum, recovered_txs}) do
    {:ok, _} =
      DB.Transaction.update_with(%{
        transactions: recovered_txs,
        blknum: blknum,
        blkhash: "##{blknum}",
        timestamp: 1_540_465_606,
        eth_height: 1
      })

    recovered_txs
    |> Enum.with_index()
    |> Enum.map(fn {recovered_tx, txindex} -> {blknum, txindex, recovered_tx.tx_hash, recovered_tx} end)
  end
end
