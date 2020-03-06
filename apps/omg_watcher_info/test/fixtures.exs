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

# unfortunately something is wrong with the fixtures loading in `test_helper.exs` and the following needs to be done
Code.require_file("#{__DIR__}/../../omg_child_chain/test/omg_child_chain/integration/fixtures.exs")

defmodule OMG.WatcherInfo.Fixtures do
  use ExUnitFixtures.FixtureModule

  use OMG.Eth.Fixtures
  use OMG.DB.Fixtures
  use OMG.ChildChain.Integration.Fixtures
  use OMG.Utils.LoggerExt

  alias OMG.Crypto
  alias OMG.WatcherInfo.DB

  @eth OMG.Eth.RootChain.eth_pseudo_address()

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

  deffixture initial_deposits(alice, bob) do
    deposits = [
      %{
        root_chain_txhash: Crypto.hash(<<1000::256>>),
        log_index: 0,
        owner: alice.addr,
        currency: @eth,
        amount: 333,
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
        blknum: 2
      }
    ]

    # Initial data depending tests can reuse
    DB.EthEvent.insert_deposits!(deposits)
    :ok
  end

  deffixture blocks_inserter() do
    fn blocks -> Enum.flat_map(blocks, &prepare_one_block/1) end
  end

  defp prepare_one_block({blknum, recovered_txs}) do
    {:ok, _} =
      DB.Block.insert_with_transactions(%{
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
