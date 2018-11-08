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

  alias OMG.API
  alias OMG.Eth
  alias OMG.JSONRPC.Client
  alias OMG.Watcher.Eventer.Event
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest
  alias OMG.Watcher.Web.Channel

  @moduletag :integration

  @timeout 40_000
  @eth API.Crypto.zero_address()

  @endpoint OMG.Watcher.Web.Endpoint

  @tag fixtures: [:watcher_sandbox, :stable_alice, :child_chain, :token, :stable_alice_deposits]
  test "exit which is using already spent utxo from transaction causes to emit invalid_exit event", %{
    stable_alice: alice,
    stable_alice_deposits: {deposit_blknum, _}
  } do
    {:ok, _, _socket} = subscribe_and_join(socket(), Channel.Byzantine, "byzantine")

    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
    {:ok, %{blknum: deposit_blknum}} = Client.call(:submit, %{transaction: tx})

    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
    {:ok, %{blknum: tx_blknum, tx_hash: _tx_hash}} = Client.call(:submit, %{transaction: tx})

    IntegrationTest.wait_until_block_getter_fetches_block(tx_blknum, @timeout)

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

    # TODO: make event payload testing approximate not exact, so that we needn't parse
    {:ok, %{"status" => "0x1", "blockNumber" => "0x" <> eth_height}} = Eth.WaitFor.eth_receipt(txhash, @timeout)
    {eth_height, ""} = Integer.parse(eth_height, 16)

    invalid_exit_event =
      Client.encode(%Event.InvalidExit{
        amount: 10,
        currency: @eth,
        owner: alice.addr,
        utxo_pos: utxo_pos,
        eth_height: eth_height
      })

    assert_push("invalid_exit", ^invalid_exit_event, 5_000)
  end

  @tag fixtures: [:watcher_sandbox, :stable_alice, :child_chain, :token, :stable_alice_deposits]
  test "transaction which is using already spent utxo from exit and happened before end of margin of slow validator (m_sv) causes to emit invalid_exit event ",
       %{stable_alice: alice, stable_alice_deposits: {deposit_blknum, _}} do
    margin_slow_validator =
      Application.get_env(:omg_watcher, :margin_slow_validator) * Application.get_env(:omg_eth, :child_block_interval)

    # TODO remove this tx , use directly deposit_blknum to get_exit_data
    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
    {:ok, %{blknum: exit_blknum}} = Client.call(:submit, %{transaction: tx})

    # Here we calcualted bad_block_number by adding `exit_blknum` and `margin_slow_validator` / 2
    # to have guarantee that bad_block_number will be after margin of slow validator(m_sv)
    bad_block_number = exit_blknum + div(margin_slow_validator, 2)
    bad_tx = API.TestHelper.create_recovered([{exit_blknum, 0, 0, alice}], @eth, [{alice, 10}])

    %{hash: bad_block_hash, number: _, transactions: _} =
      bad_block = API.Block.hashed_txs_at([bad_tx], bad_block_number)

    # Here we manually submiting invalid block with big/future nonce to the Rootchain to make
    # the Rootchain to mine invalid block instead of block submitted by child chain
    {:ok, child_block_interval} = Eth.RootChain.get_child_block_interval()
    nonce = div(bad_block_number, child_block_interval)
    {:ok, _} = OMG.Eth.RootChain.submit_block(bad_block_hash, nonce, 1)

    # from now on the child chain server is broken until end of test
    OMG.Watcher.Integration.BadChildChainServer.register_and_start_server(bad_block)

    {:ok, _, _socket} = subscribe_and_join(socket(), Channel.Byzantine, "byzantine")

    IntegrationTest.wait_until_block_getter_fetches_block(exit_blknum, @timeout)

    %{
      "txbytes" => txbytes,
      "proof" => proof,
      "sigs" => sigs,
      "utxo_pos" => utxo_pos
    } = IntegrationTest.get_exit_data(exit_blknum, 0, 0)

    {:ok, txhash} =
      Eth.RootChain.start_exit(
        utxo_pos,
        txbytes,
        proof,
        sigs,
        alice.addr
      )

    # TODO: make event payload testing approximate not exact, so that we needn't parse
    {:ok, %{"status" => "0x1", "blockNumber" => "0x" <> eth_height}} = Eth.WaitFor.eth_receipt(txhash, @timeout)
    {eth_height, ""} = Integer.parse(eth_height, 16)

    # Here we waiting for block `bad_block_number + 1`
    # to give time for watcher to fetch and validate bad_block_number
    # remember not to wait too much, as the `BlockGetter` will stop after exit gets old
    IntegrationTest.wait_until_block_getter_fetches_block(bad_block_number + 1, @timeout)

    invalid_exit_event =
      Client.encode(%Event.InvalidExit{
        amount: 10,
        currency: @eth,
        owner: alice.addr,
        utxo_pos: utxo_pos,
        eth_height: eth_height
      })

    assert_push("invalid_exit", ^invalid_exit_event)
  end
end
