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

defmodule OMG.Watcher.Integration.BlockGetter1Test do
  @moduledoc """
  This test is intended to be the major smoke/integration test of the Watcher

  It tests whether valid/invalid blocks, deposits and exits are tracked correctly within the Watcher
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures
  use OMG.Watcher.Integration.Fixtures
  use Plug.Test

  require OMG.Utxo

  alias OMG.Eth.RootChain
  alias OMG.Eth.Support.BlockSubmission.Integration
  alias OMG.Watcher.BlockGetter
  alias OMG.Watcher.Event
  alias OMG.Watcher.Integration.BadChildChainServer
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest
  alias Support.DevHelper
  alias Support.RootChainHelper
  alias Support.WatcherHelper

  @timeout 40_000
  @eth <<0::160>>

  @moduletag :mix_based_child_chain

  @moduletag timeout: 150_000

  @tag fixtures: [:in_beam_watcher, :stable_alice, :token, :stable_alice_deposits, :test_server]
  test "transaction which is spending an exiting output before the `sla_margin` causes an invalid_exit event only",
       %{stable_alice: alice, stable_alice_deposits: {deposit_blknum, _}, test_server: context} do
    Process.sleep(12_000)
    tx = OMG.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 9}])
    %{"blknum" => exit_blknum} = WatcherHelper.submit(tx)

    # Here we're preparing invalid block
    bad_block_number = 2_000
    bad_tx = OMG.TestHelper.create_recovered([{exit_blknum, 0, 0, alice}], @eth, [{alice, 9}])

    %{hash: bad_block_hash, number: _, transactions: _} =
      bad_block = OMG.Block.hashed_txs_at([bad_tx], bad_block_number)

    # from now on the child chain server is broken until end of test
    route = BadChildChainServer.prepare_route_to_inject_bad_block(context, bad_block)

    :sys.replace_state(BlockGetter, fn state ->
      config = state.config
      new_config = %{config | child_chain_url: "http://localhost:#{route.port}"}
      %{state | config: new_config}
    end)

    IntegrationTest.wait_for_block_fetch(exit_blknum, @timeout)
    Process.sleep(12_000)
    txindex = 0
    oindex = 0

    %{
      "txbytes" => txbytes,
      "proof" => proof,
      "utxo_pos" => utxo_pos
    } = WatcherHelper.get_exit_data(exit_blknum, txindex, oindex)

    {:ok, %{"status" => "0x1", "blockNumber" => _eth_height}} =
      utxo_pos
      |> RootChainHelper.start_exit(
        txbytes,
        proof,
        alice.addr
      )
      |> DevHelper.transact_sync!()

    # THIS IS CHILDCHAIN CODE

    # Here we're manually submitting invalid block to the root chain
    # NOTE: this **must** come after `start_exit` is mined (see just above) but still not later than
    #       `sla_margin` after exit start, hence the `config/test.exs` entry for the margin is rather high
    gas_price = 1
    nonce = RootChain.next_child_block() / 1000
    {:ok, _} = Integration.submit_block(bad_block_hash, round(nonce - 1), gas_price)

    IntegrationTest.wait_for_byzantine_events([%Event.InvalidExit{}.name], @timeout)
  end
end
