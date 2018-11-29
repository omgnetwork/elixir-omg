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
  alias OMG.API.Utxo
  require Utxo
  alias OMG.Eth
  alias OMG.JSONRPC.Client
  alias OMG.Watcher.Eventer.Event
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest
  alias OMG.Watcher.TestHelper, as: Test
  alias OMG.Watcher.Web.Channel
  alias OMG.Watcher.Web.Serializer.Response

  @moduletag :integration

  @timeout 40_000
  @eth API.Crypto.zero_address()

  @endpoint OMG.Watcher.Web.Endpoint

  @tag fixtures: [:watcher_sandbox, :stable_alice, :child_chain, :token, :stable_alice_deposits]
  test "exit which is using already spent utxo from transaction causes to emit invalid_exit event", %{
    stable_alice: alice,
    stable_alice_deposits: {deposit_blknum, _}
  } do
    {:ok, _, event_socket} = subscribe_and_join(socket(), Channel.Byzantine, "byzantine")

    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], [{alice, @eth, 10}])
    {:ok, %{blknum: deposit_blknum}} = Client.call(:submit, %{transaction: tx})

    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], [{alice, @eth, 10}])
    {:ok, %{blknum: tx_blknum, tx_hash: _tx_hash}} = Client.call(:submit, %{transaction: tx})

    IntegrationTest.wait_for_block_fetch(tx_blknum, @timeout)

    %{
      "txbytes" => txbytes,
      "proof" => proof,
      "sigs" => sigs,
      "utxo_pos" => utxo_pos
    } = IntegrationTest.get_exit_data(deposit_blknum, 0, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      Eth.RootChain.start_exit(
        utxo_pos,
        txbytes,
        proof,
        sigs,
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    invalid_exit_event =
      Client.encode(%Event.InvalidExit{
        amount: 10,
        currency: @eth,
        owner: alice.addr,
        utxo_pos: utxo_pos,
        eth_height: eth_height
      })

    assert_push("invalid_exit", ^invalid_exit_event, 5_000)

    # after the notification has been received, a challenged is composed and sent
    challenge = get_exit_challenge(deposit_blknum, 0, 0)
    assert {:ok, {alice.addr, @eth, 10}} == Eth.RootChain.get_exit(utxo_pos)

    {:ok, %{"status" => "0x1"}} =
      OMG.Eth.RootChain.challenge_exit(
        challenge["cutxopos"],
        challenge["eutxoindex"],
        challenge["txbytes"],
        challenge["proof"],
        challenge["sigs"],
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    assert {:ok, {API.Crypto.zero_address(), @eth, 10}} == Eth.RootChain.get_exit(utxo_pos)

    IntegrationTest.wait_for_current_block_fetch(@timeout)

    # re subscribe fresh, so we don't get old events in the socket
    Process.unlink(event_socket.channel_pid)
    :ok = close(event_socket)
    clear_mailbox()

    {:ok, _, _socket} = subscribe_and_join(socket(), Channel.Byzantine, "byzantine")

    # no more pestering the user, the invalid exit is gone
    refute_push("invalid_exit", _, 2_000)
  end

  # clears the mailbox of `self()`. Useful to purge old events that shouldn't be emitted anymore after some action
  defp clear_mailbox do
    receive do
      _ -> clear_mailbox()
    after
      0 -> :ok
    end
  end

  defp get_exit_challenge(blknum, txindex, oindex) do
    utxo_pos = Utxo.position(blknum, txindex, oindex) |> Utxo.Position.encode()

    assert %{"result" => "success", "data" => data} = Test.rest_call(:get, "utxo/#{utxo_pos}/challenge_data")

    Response.decode16(data, ["txbytes", "proof", "sigs"])
  end

  @tag fixtures: [:watcher_sandbox, :stable_alice, :child_chain, :token, :stable_alice_deposits]
  test "transaction which is using already spent utxo from exit and happened before end of margin of slow validator (m_sv) causes to emit invalid_exit event ",
       %{stable_alice: alice, stable_alice_deposits: {deposit_blknum, _}} do
    margin_slow_validator =
      Application.get_env(:omg_watcher, :margin_slow_validator) * Application.get_env(:omg_eth, :child_block_interval)

    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], [{alice, @eth, 10}])
    {:ok, %{blknum: exit_blknum}} = Client.call(:submit, %{transaction: tx})

    # Here we calcualted bad_block_number by adding `exit_blknum` and `margin_slow_validator` / 2
    # to have guarantee that bad_block_number will be after margin of slow validator(m_sv)
    bad_block_number = exit_blknum + div(margin_slow_validator, 2)
    bad_tx = API.TestHelper.create_recovered([{exit_blknum, 0, 0, alice}], [{alice, @eth, 10}])

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

    IntegrationTest.wait_for_block_fetch(exit_blknum, @timeout)

    %{
      "txbytes" => txbytes,
      "proof" => proof,
      "sigs" => sigs,
      "utxo_pos" => utxo_pos
    } = IntegrationTest.get_exit_data(exit_blknum, 0, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      Eth.RootChain.start_exit(
        utxo_pos,
        txbytes,
        proof,
        sigs,
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    # Here we waiting for block `bad_block_number + 1`
    # to give time for watcher to fetch and validate bad_block_number
    IntegrationTest.wait_for_block_fetch(bad_block_number + 1, @timeout)

    invalid_exit_event =
      Client.encode(%Event.InvalidExit{
        amount: 10,
        currency: @eth,
        owner: alice.addr,
        utxo_pos: utxo_pos,
        eth_height: eth_height
      })

    assert_push("invalid_exit", ^invalid_exit_event, 1500)
  end
end
