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

defmodule OMG.Watcher.Integration.BlockGetter3Test do
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

  import ExUnit.CaptureLog, only: [capture_log: 1]

  alias OMG.Eth
  alias OMG.Watcher.Event
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest
  alias Support.DevHelper
  alias Support.RootChainHelper
  alias Support.WatcherHelper
  alias OMG.Eth.Support.BlockSubmission.Integration

  @timeout 40_000
  @eth <<0::160>>

  @moduletag :mix_based_child_chain

  @moduletag timeout: 100_000

  @tag fixtures: [:in_beam_watcher, :stable_alice, :token, :stable_alice_deposits]
  test "block getting halted by block withholding doesn't halt detection of new invalid exits", %{
    stable_alice: alice,
    stable_alice_deposits: {deposit_blknum, _}
  } do
    Process.sleep(11_000)
    tx = OMG.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 9}])
    %{"blknum" => deposit_blknum} = WatcherHelper.submit(tx)

    tx = OMG.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 8}])
    %{"blknum" => tx_blknum, "txhash" => _tx_hash} = WatcherHelper.submit(tx)

    IntegrationTest.wait_for_block_fetch(tx_blknum, @timeout)

    {_, nonce} = get_next_blknum_nonce(tx_blknum)

    {:ok, _txhash} = Integration.submit_block(<<0::256>>, nonce, 20_000_000_000)

    # checking if both machines and humans learn about the byzantine condition
    assert capture_log(fn ->
             IntegrationTest.wait_for_byzantine_events([%Event.BlockWithholding{}.name], @timeout)
           end) =~ inspect(:withholding)

    %{
      "txbytes" => txbytes,
      "proof" => proof,
      "utxo_pos" => utxo_pos
    } = WatcherHelper.get_exit_data(deposit_blknum, 0, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => _eth_height}} =
      utxo_pos
      |> RootChainHelper.start_exit(
        txbytes,
        proof,
        alice.addr
      )
      |> DevHelper.transact_sync!()

    IntegrationTest.wait_for_byzantine_events([%Event.BlockWithholding{}.name, %Event.InvalidExit{}.name], @timeout)
  end

  defp get_next_blknum_nonce(blknum) do
    child_block_interval = Application.fetch_env!(:omg_eth, :child_block_interval)
    next_blknum = blknum + child_block_interval
    {next_blknum, trunc(next_blknum / child_block_interval)}
  end
end
