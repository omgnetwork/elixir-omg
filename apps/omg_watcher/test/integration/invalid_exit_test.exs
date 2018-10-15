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
  test "transaction which is using already spent utxo from exit and happened before end of m_sv causes to emit invalid_exit event ",
       %{stable_alice: alice, stable_alice_deposits: {deposit_blknum, _}} do
    defmodule BadChildChainBLock do
      use OMG.Watcher.Integration.BadChildChainBLock, blknum: 27_000
    end

    JSONRPC2.Servers.HTTP.http(BadChildChainBLock, port: BadChildChainBLock.port())

    {:ok, _, _socket} = subscribe_and_join(socket(), Channel.Byzantine, "byzantine")

    %{hash: bad_block_hash, number: bad_block_number, transactions: _} = BadChildChainBLock.bad_block()

    {:ok, _} =
      OMG.Eth.RootChain.submit_block(
        bad_block_hash,
        27,
        1
      )

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
    {:ok, current_child_block} = Eth.RootChain.get_current_child_block()

    Application.put_env(
      :omg_jsonrpc,
      :child_chain_url,
      "http://localhost:" <> Integer.to_string(BadChildChainBLock.port())
    )

    slow_exit_validator_block_margin =
      Application.get_env(:omg_watcher, :slow_exit_validator_block_margin) *
        Application.get_env(:omg_eth, :child_block_interval)

    after_m_sv = current_child_block + slow_exit_validator_block_margin

    assert bad_block_number < after_m_sv

    IntegrationTest.wait_until_block_getter_fetches_block(after_m_sv, @timeout)

    invalid_exit_event =
      Client.encode(%Event.InvalidExit{
        amount: 10,
        currency: @eth,
        owner: alice.addr,
        utxo_pos: utxo_pos
      })

    assert_push("invalid_exit", ^invalid_exit_event)

    JSONRPC2.Servers.HTTP.shutdown(BadChildChainBLock)

    Application.put_env(:omg_jsonrpc, :child_chain_url, "http://localhost:9656")
  end

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

    {:ok, %{"status" => "0x1"}} = Eth.WaitFor.eth_receipt(txhash, @timeout)

    Process.sleep(1_000)

    invalid_exit_event =
      Client.encode(%Event.InvalidExit{
        amount: 10,
        currency: @eth,
        owner: alice.addr,
        utxo_pos: utxo_pos
      })

    assert_push("invalid_exit", ^invalid_exit_event)
  end
end
