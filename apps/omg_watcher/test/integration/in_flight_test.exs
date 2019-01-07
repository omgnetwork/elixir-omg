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

defmodule OMG.Watcher.Integration.In_flight_test do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.API.Fixtures
  use OMG.API.Integration.Fixtures

  use Plug.Test
  use Phoenix.ChannelTest

  alias OMG.API
  alias OMG.API.Crypto
  alias OMG.API.Utxo
  require Utxo
  alias OMG.Eth
  alias OMG.RPC.Client
  alias OMG.Watcher.Eventer.Event
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest
  alias OMG.Watcher.Integration.TestServer
  alias OMG.Watcher.TestHelper
  alias OMG.Watcher.Web.Channel
  alias OMG.Watcher.Web.Serializers.Response

  import ExUnit.CaptureLog

  @moduletag :integration44

  @timeout 40_000
  @eth Crypto.zero_address()
  @eth_hex String.duplicate("00", 20)

  @endpoint OMG.Watcher.Web.Endpoint
  @empty_utxo %{"amount" => 0, "blknum" => 0, "txindex" => 0, "oindex" => 0, "currency" => nil, "txbytes" => nil}

  @tag fixtures: [:watcher_sandbox, :child_chain, :alice, :bob, :alice_deposits, :token]
  test "get the blocks from child chain after sending a transaction and start exit", %{
    alice: alice,
    bob: bob,
    token: token,
    alice_deposits: {deposit_blknum, token_deposit_blknum}
  } do
    # alice checks whether she can IFE in case her tx gets lost
    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 7}, {bob, 3}])
    assert {:ok, in_flight_exit_info} = OMG.Watcher.API.get_in_flight_exit(tx)

    {:ok, %{"status" => "0x1"}} =
      Eth.RootChain.start_in_flight_exit(
      in_flight_exit_info[:in_flight_tx],
      in_flight_exit_info[:input_txs],
      in_flight_exit_info[:input_txs_inclusion_proofs],
      in_flight_exit_info[:in_flight_tx_sigs],
      alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    Eth.RootChain.piggyback_in_flight_exit(in_flight_exit_info[:in_flight_tx],4, alice.addr) 
    |> Eth.DevHelpers.transact_sync!()

    assert [] == IntegrationTest.get_utxos(alice)
    assert [] == IntegrationTest.get_utxos(bob)
  end

  defp get_block_submitted_event_height(block_number) do
    {:ok, height} = Eth.get_ethereum_height()
    {:ok, block_submissions} = Eth.RootChain.get_block_submitted_events({1, height})
    [%{eth_height: eth_height}] = Enum.filter(block_submissions, fn submission -> submission.blknum == block_number end)
    eth_height
  end

  defp assert_block_getter_down do
    :ok = TestHelper.wait_for_process(Process.whereis(OMG.Watcher.BlockGetter))
  end
end
