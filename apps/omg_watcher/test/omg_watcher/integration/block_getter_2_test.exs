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

defmodule OMG.Watcher.Integration.BlockGetter2Test do
  @moduledoc """
  This test is intended to be the major smoke/integration test of the Watcher

  It tests whether valid/invalid blocks, deposits and exits are tracked correctly within the Watcher
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Watcher.Fixtures
  use OMG.Watcher.Integration.Fixtures
  use Plug.Test

  require OMG.Watcher.Utxo

  alias OMG.Eth
  alias OMG.Watcher.BlockGetter
  alias OMG.Watcher.Event
  alias OMG.Watcher.Integration.BadChildChainServer
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest
  alias OMG.Watcher.TestHelper
  alias Support.DevHelper
  alias Support.RootChainHelper
  alias Support.WatcherHelper

  @timeout 60_000
  @eth <<0::160>>

  @moduletag :mix_based_child_chain

  @moduletag timeout: 180_000

  @tag fixtures: [:in_beam_watcher, :stable_alice, :token, :stable_alice_deposits, :test_server]
  test "transaction which is spending an exiting output after the `sla_margin` causes an unchallenged_exit event",
       %{stable_alice: alice, stable_alice_deposits: {deposit_blknum, _}, test_server: context} do
    Process.sleep(12_000)

    tx = TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 9}])
    %{"blknum" => exit_blknum} = WatcherHelper.submit(tx)

    # Here we're preparing invalid block
    bad_tx = OMG.Watcher.TestHelper.create_recovered([{exit_blknum, 0, 0, alice}], @eth, [{alice, 9}])

    bad_block_number = 2_000

    %{hash: bad_block_hash, number: _, transactions: _} =
      bad_block = OMG.Watcher.Block.hashed_txs_at([bad_tx], bad_block_number)

    # from now on the child chain server is broken until end of test
    route = BadChildChainServer.prepare_route_to_inject_bad_block(context, bad_block)

    :sys.replace_state(BlockGetter, fn state ->
      config = state.config
      new_config = %{config | child_chain_url: "http://localhost:#{route.port}"}
      %{state | config: new_config}
    end)

    IntegrationTest.wait_for_block_fetch(exit_blknum, @timeout)
    Process.sleep(10_000)

    %{
      "txbytes" => txbytes,
      "proof" => proof,
      "utxo_pos" => utxo_pos
    } = WatcherHelper.get_exit_data(exit_blknum, 0, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      utxo_pos
      |> RootChainHelper.start_exit(
        txbytes,
        proof,
        alice.addr
      )
      |> DevHelper.transact_sync!()

    exit_processor_sla_margin = Application.fetch_env!(:omg_watcher, :exit_processor_sla_margin)
    DevHelper.wait_for_root_chain_block(eth_height + exit_processor_sla_margin, @timeout)

    # checking if both machines and humans learn about the byzantine condition
    assert WatcherHelper.capture_log(fn ->
             # Here we're manually submitting invalid block to the root chain
             # THIS IS CHILDCHAIN CODE
             {:ok, _} = Eth.submit_block(bad_block_hash, 2, 1)

             IntegrationTest.wait_for_byzantine_events(
               [%Event.InvalidExit{}.name, %Event.UnchallengedExit{}.name],
               @timeout
             )
           end) =~ inspect(:unchallenged_exit)

    # we should still be able to challenge this "unchallenged exit" - just smoke testing the endpoint, details elsewhere
    WatcherHelper.get_exit_challenge(exit_blknum, 0, 0)
  end
end
