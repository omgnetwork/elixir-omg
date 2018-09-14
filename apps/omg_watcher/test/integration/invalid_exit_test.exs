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

defmodule OMG.Watcher.Integration.InvalidExitTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.API.Fixtures
  use OMG.API.Integration.Fixtures
  use Plug.Test
  use Phoenix.ChannelTest

  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest
  alias OMG.API.Crypto
  alias OMG.Eth
  alias OMG.API
  alias OMG.JSONRPC.Client
  alias OMG.Watcher.Eventer.Event
  alias OMG.Watcher.Web.Channel

  @moduletag :integration
  @timeout 40_000
  @eth OMG.API.Crypto.zero_address()
  @endpoint OMG.Watcher.Web.Endpoint

  #  TODO complete this test
  @tag fixtures: [:watcher_sandbox, :child_chain, :alice, :alice_deposits]
  @tag :skip
  test "transaction which is using already spent utxo from exit and happened before end of m_sv causes to emit invalid_exit event ",
       %{alice: alice, alice_deposits: {deposit_blknum, _}} do
  end

  #  TODO compelte this test
  @tag fixtures: [:watcher_sandbox, :alice, :alice_deposits]
  @tag :skip
  test "transaction which is using already spent utxo from exit and happened after m_sv causes to emit invalid_block event",
       %{alice: alice, alice_deposits: {deposit_blknum, _}} do
    {:ok, _, _socket} = subscribe_and_join(socket(), Channel.Byzantine, "byzantine")

    # TODO remove this tx , use directly deposit_blknum to get_exit_data
    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
    {:ok, %{blknum: deposit_blknum}} = Client.call(:submit, %{transaction: tx})

    IntegrationTest.wait_until_block_getter_fetches_block(deposit_blknum, @timeout)

    %{
      "txbytes" => txbytes,
      "proof" => proof,
      "sigs" => sigs,
      "utxo_pos" => utxo_pos
    } = IntegrationTest.get_exit_data(deposit_blknum, 0, 0)

    {:ok, txhash} =
      Eth.RootChain.start_exit(
        utxo_pos,
        txbytes,
        proof,
        sigs,
        alice.addr
      )

    {:ok, %{"status" => "0x1"}} = Eth.WaitFor.eth_receipt(txhash, @timeout)

    slow_exit_validator_block_margin = Application.get_env(:omg_watcher, :slow_exit_validator_block_margin)
    {:ok, current_child_block} = Eth.RootChain.get_current_child_block()

    after_m_sv = current_child_block + slow_exit_validator_block_margin

    IntegrationTest.wait_until_block_getter_fetches_block(after_m_sv, @timeout)

    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
    {:ok, %{blknum: double_spend_block_nr, tx_hash: tx_hash}} = Client.call(:submit, %{transaction: tx})

    invalid_block_event =
      Client.encode(%Event.InvalidBlock{
        error_type: :tx_execution,
        hash: <<>>,
        number: double_spend_block_nr
      })

    # TODO invalid_block_event => ^invalid_block_event
    assert_push("invalid_block", invalid_block_event, 4_0000)
  end
end
