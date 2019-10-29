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

defmodule OMG.Watcher.Integration.StandardExitTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures
  use OMG.ChildChain.Integration.Fixtures
  use Plug.Test
  use Phoenix.ChannelTest

  alias OMG.Eth
  alias OMG.Utils.HttpRPC.Response
  alias OMG.Utxo
  alias OMG.Watcher.Event
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest
  alias Support.DevHelper
  alias Support.RootChainHelper
  alias Support.WatcherHelper

  require Utxo

  @moduletag :integration
  @moduletag :watcher
  @moduletag timeout: 180_000

  @endpoint OMG.WatcherRPC.Web.Endpoint

  @timeout 40_000
  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @tag fixtures: [:watcher, :stable_alice, :child_chain, :token, :stable_alice_deposits]
  test "exit finalizes", %{
    stable_alice: alice,
    stable_alice_deposits: {deposit_blknum, _}
  } do
    {:ok, _, _socket} =
      subscribe_and_join(
        socket(OMG.WatcherRPC.Web.Socket),
        OMG.WatcherRPC.Web.Channel.Exit,
        WatcherHelper.create_topic("exit", Eth.Encoding.to_hex(alice.addr))
      )

    tx = OMG.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
    %{"blknum" => tx_blknum} = WatcherHelper.submit(tx)

    IntegrationTest.wait_for_block_fetch(tx_blknum, @timeout)

    %{
      "txbytes" => txbytes,
      "proof" => proof,
      "utxo_pos" => utxo_pos
    } = WatcherHelper.get_exit_data(tx_blknum, 0, 0)

    {:ok, %{"status" => "0x1"}} =
      RootChainHelper.start_exit(
        utxo_pos,
        txbytes,
        proof,
        alice.addr
      )
      |> DevHelper.transact_sync!()

    :ok = IntegrationTest.process_exits(1, @eth, alice)

    expected_event =
      %Event.ExitFinalized{
        currency: @eth,
        amount: 10,
        child_blknum: tx_blknum,
        child_txindex: 0,
        child_oindex: 0
      }
      |> Response.sanitize()

    assert_push("exit_finalized", ^expected_event)
  end
end
