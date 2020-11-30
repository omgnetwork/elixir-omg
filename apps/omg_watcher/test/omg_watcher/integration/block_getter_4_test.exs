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

defmodule OMG.Watcher.Integration.BlockGetter4Test do
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

  alias OMG.Eth
  alias OMG.Watcher.BlockGetter
  alias OMG.Watcher.Event
  alias OMG.Watcher.Integration.BadChildChainServer
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest
  alias Support.WatcherHelper

  @timeout 40_000
  @eth OMG.Eth.zero_address()

  @moduletag :mix_based_child_chain

  @moduletag timeout: 100_000

  @tag fixtures: [:in_beam_watcher, :test_server, :stable_alice, :stable_alice_deposits]
  test "operator claimed fees incorrectly (too much | little amount, not collected token)", %{
    stable_alice: alice,
    test_server: context,
    stable_alice_deposits: {deposit_blknum, _}
  } do
    Process.sleep(11_000)
    fee_claimer = OMG.Configuration.fee_claimer_address()

    # preparing transactions for a fake block that overclaim fees
    txs = [
      OMG.TestHelper.create_recovered([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 9}]),
      OMG.TestHelper.create_recovered([{1000, 0, 0, alice}], @eth, [{alice, 8}]),
      OMG.TestHelper.create_recovered_fee_tx(1000, fee_claimer, @eth, 3)
    ]

    block_overclaiming_fees = OMG.Block.hashed_txs_at(txs, 1000)

    # from now on the child chain server is broken until end of test
    route =
      BadChildChainServer.prepare_route_to_inject_bad_block(
        context,
        block_overclaiming_fees
      )

    :sys.replace_state(BlockGetter, fn state ->
      config = state.config
      new_config = %{config | child_chain_url: "http://localhost:#{route.port}"}
      %{state | config: new_config}
    end)

    # checking if both machines and humans learn about the byzantine condition
    assert WatcherHelper.capture_log(fn ->
             {:ok, _txhash} = Eth.submit_block(block_overclaiming_fees.hash, 1, 20_000_000_000)
             IntegrationTest.wait_for_byzantine_events([%Event.InvalidBlock{}.name], @timeout)
           end) =~ inspect({:tx_execution, :claimed_and_collected_amounts_mismatch})
  end
end
