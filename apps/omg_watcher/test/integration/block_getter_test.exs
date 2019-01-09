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

defmodule OMG.Watcher.Integration.BlockGetterTest do
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

  @moduletag :integration

  @timeout 40_000
  @eth Crypto.zero_address()
  @eth_hex String.duplicate("00", 20)

  @endpoint OMG.Watcher.Web.Endpoint

  @tag fixtures: [:watcher_sandbox, :child_chain, :alice, :bob, :alice_deposits, :token]
  test "get the blocks from child chain after sending a transaction and start exit", %{
    alice: alice,
    bob: bob,
    token: token,
    alice_deposits: {deposit_blknum, token_deposit_blknum}
  } do
    {:ok, alice_address} = Crypto.encode_address(alice.addr)

    token_addr = token |> Base.encode16()

    token_deposit = %{
      "amount" => 10,
      "blknum" => token_deposit_blknum,
      "txindex" => 0,
      "oindex" => 0,
      "currency" => token_addr,
      "txbytes" => nil
    }

    {:ok, _, _socket} =
      subscribe_and_join(socket(), Channel.Transfer, TestHelper.create_topic("transfer", alice_address))

    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 7}, {bob, 3}])
    {:ok, %{blknum: block_nr}} = Client.submit(tx)

    IntegrationTest.wait_for_block_fetch(block_nr, @timeout)

    encode_tx = Base.encode16(tx)

    assert [
             %{
               "amount" => 3,
               "blknum" => ^block_nr,
               "txindex" => 0,
               "oindex" => 1,
               "currency" => @eth_hex,
               "txbytes" => ^encode_tx
             }
           ] = IntegrationTest.get_utxos(bob)

    assert [
             ^token_deposit,
             %{
               "amount" => 7,
               "blknum" => ^block_nr,
               "txindex" => 0,
               "oindex" => 0,
               "currency" => @eth_hex,
               "txbytes" => ^encode_tx
             }
           ] = IntegrationTest.get_utxos(alice)

    {:ok, recovered_tx} = API.Core.recover_tx(tx)
    {:ok, {block_hash, _}} = Eth.RootChain.get_child_chain(block_nr)

    event_eth_height = get_block_submitted_event_height(block_nr)

    address_received_event =
      %Event.AddressReceived{
        tx: recovered_tx,
        child_blknum: block_nr,
        child_txindex: 0,
        child_block_hash: block_hash,
        submited_at_ethheight: event_eth_height
      }
      |> Response.clean_artifacts()

    address_spent_event =
      %Event.AddressSpent{
        tx: recovered_tx,
        child_blknum: block_nr,
        child_txindex: 0,
        child_block_hash: block_hash,
        submited_at_ethheight: event_eth_height
      }
      |> Response.clean_artifacts()

    assert_push("address_received", ^address_received_event)

    assert_push("address_spent", ^address_spent_event)

    %{
      "utxo_pos" => utxo_pos,
      "txbytes" => txbytes,
      "proof" => proof
    } = IntegrationTest.get_exit_data(block_nr, 0, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => exit_eth_height}} =
      Eth.RootChain.start_exit(
        utxo_pos,
        txbytes,
        proof,
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    utxo_pos = Utxo.position(block_nr, 0, 0) |> Utxo.Position.encode()

    assert {:ok, [%{amount: 7, utxo_pos: utxo_pos, owner: alice.addr, currency: @eth, eth_height: exit_eth_height}]} ==
             Eth.RootChain.get_exits(0, exit_eth_height)

    # Here we're waiting for watcher to process the exits
    deposit_finality_margin = Application.fetch_env!(:omg_api, :deposit_finality_margin)
    Eth.DevHelpers.wait_for_root_chain_block(exit_eth_height + deposit_finality_margin + 1 + 1)

    tx2 = API.TestHelper.create_encoded([{block_nr, 0, 0, alice}], @eth, [{alice, 7}])

    {:error, {:client_error, %{"code" => "submit:utxo_not_found"}}} = Client.submit(tx2)
  end

  defp get_block_submitted_event_height(block_number) do
    {:ok, height} = Eth.get_ethereum_height()
    {:ok, block_submissions} = Eth.RootChain.get_block_submitted_events({1, height})
    [%{eth_height: eth_height}] = Enum.filter(block_submissions, fn submission -> submission.blknum == block_number end)
    eth_height
  end

  @tag fixtures: [:watcher_sandbox, :token, :child_chain, :alice, :alice_deposits]
  test "exit erc20, without challenging an invalid exit", %{
    token: token,
    alice: alice,
    alice_deposits: {_, token_deposit_blknum}
  } do
    token_tx = API.TestHelper.create_encoded([{token_deposit_blknum, 0, 0, alice}], token, [{alice, 10}])

    # spend the token deposit
    {:ok, %{blknum: spend_token_child_block}} = Client.submit(token_tx)

    IntegrationTest.wait_for_block_fetch(spend_token_child_block, @timeout)

    %{
      "txbytes" => txbytes,
      "proof" => proof,
      "utxo_pos" => utxo_pos
    } = IntegrationTest.get_exit_data(spend_token_child_block, 0, 0)

    {:ok, _} =
      Eth.RootChain.start_exit(
        utxo_pos,
        txbytes,
        proof,
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()
  end

  @tag fixtures: [:watcher_sandbox, :test_server]
  test "different hash send by child chain", %{test_server: context} do
    different_hash = <<0::256>>
    different_hash_encoded = Base.encode16(different_hash)

    TestServer.with_route(
      context,
      "/block.get",
      TestServer.make_response(%{
        transactions: [],
        number: 1000,
        # different hash than expected
        hash: different_hash_encoded
      })
    )

    {:ok, _txhash} = Eth.RootChain.submit_block(different_hash, 1, 20_000_000_000)

    invalid_block_event = %{"error_type" => "incorrect_hash", "hash" => different_hash_encoded, "number" => 1000}

    IntegrationTest.wait_for_byzantine_events([invalid_block_event], @timeout)
  end

  @tag fixtures: [:watcher_sandbox, :alice, :test_server]
  test "bad transaction with not existing utxo, detected by interactions with State", %{
    alice: alice,
    test_server: context
  } do
    # preparing block with invalid transaction
    recovered = API.TestHelper.create_recovered([{1, 0, 0, alice}], Crypto.zero_address(), [{alice, 10}])
    block_with_incorrect_transaction = API.Block.hashed_txs_at([recovered], 1000)

    block_response =
      block_with_incorrect_transaction
      |> Response.clean_artifacts()
      |> TestServer.make_response()

    TestServer.with_route(context, "/block.get", block_response)

    invalid_block_hash = block_with_incorrect_transaction.hash

    {:ok, _txhash} = Eth.RootChain.submit_block(invalid_block_hash, 1, 20_000_000_000)

    invalid_block_event = %{"error_type" => "tx_execution", "hash" => invalid_block_hash, "number" => 1000}

    IntegrationTest.wait_for_byzantine_events([invalid_block_event], @timeout)
  end

  @tag fixtures: [:watcher_sandbox, :stable_alice, :child_chain, :token, :stable_alice_deposits, :test_server]
  test "transaction which is using already spent utxo from exit and happened after margin of slow validator(m_sv) causes to emit unchallenged_exit event",
       %{stable_alice: alice, stable_alice_deposits: {deposit_blknum, _}, test_server: context} do
    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
    {:ok, %{blknum: exit_blknum}} = Client.submit(tx)

    # Here we're preparing invalid block
    bad_tx = API.TestHelper.create_recovered([{exit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
    bad_block_number = 2_000

    %{hash: bad_block_hash, number: _, transactions: _} =
      bad_block = API.Block.hashed_txs_at([bad_tx], bad_block_number)

    # from now on the child chain server is broken until end of test
    OMG.Watcher.Integration.BadChildChainServer.prepare_route_to_inject_bad_block(context, bad_block, bad_block_hash)

    IntegrationTest.wait_for_block_fetch(exit_blknum, @timeout)

    %{
      "txbytes" => txbytes,
      "proof" => proof,
      "utxo_pos" => utxo_pos
    } = IntegrationTest.get_exit_data(exit_blknum, 0, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      Eth.RootChain.start_exit(
        utxo_pos,
        txbytes,
        proof,
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    # Here we're waiting for passing of margin of slow validator(m_sv)
    exit_processor_sla_margin = Application.fetch_env!(:omg_watcher, :exit_processor_sla_margin)
    Eth.DevHelpers.wait_for_root_chain_block(eth_height + exit_processor_sla_margin, @timeout)

    # Here we're manually submitting invalid block to the root chain
    {:ok, _} = OMG.Eth.RootChain.submit_block(bad_block_hash, 2, 1)

    unchallenged_exit_event = %{
      "amount" => 10,
      "currency" => @eth,
      "owner" => alice.addr,
      "utxo_pos" => utxo_pos,
      "eth_height" => eth_height
    }

    IntegrationTest.wait_for_byzantine_events([unchallenged_exit_event], @timeout)
  end
end
