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

defmodule OMG.Watcher.Integration.BlockGetterTest do
  @moduledoc """
  This test is intended to be the major smoke/integration test of the Watcher

  It tests whether valid/invalid blocks, deposits and exits are tracked correctly within the Watcher
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures
  use OMG.ChildChain.Integration.Fixtures
  use Plug.Test
  use Phoenix.ChannelTest

  alias OMG.Crypto
  alias OMG.Eth
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.Utxo
  alias OMG.Watcher
  alias OMG.WatcherRPC.Web.Channel
  alias Watcher.Event
  alias Watcher.Integration.TestHelper, as: IntegrationTest
  alias Watcher.TestHelper

  require Utxo
  import ExUnit.CaptureLog

  @moduletag :integration
  @moduletag :watcher

  @timeout 40_000
  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @endpoint OMG.WatcherRPC.Web.Endpoint

  @zero_address_hex Eth.zero_address() |> Eth.Encoding.to_hex()

  @tag timeout: 100_000
  @tag fixtures: [:watcher, :child_chain, :alice, :bob, :alice_deposits, :token]
  test "get the blocks from child chain after sending a transaction and start exit", %{
    alice: %{addr: alice_addr} = alice,
    bob: bob,
    token: token,
    alice_deposits: {deposit_blknum, token_deposit_blknum}
  } do
    {:ok, alice_address} = Crypto.encode_address(alice.addr)

    token_addr = token |> Encoding.to_hex()

    # utxo from deposit should be available
    assert [%{"blknum" => ^deposit_blknum}, %{"blknum" => ^token_deposit_blknum, "currency" => ^token_addr}] =
             TestHelper.get_utxos(alice.addr)

    # start spending and exiting to see if watcher integrates all the pieces
    {:ok, _, _socket} =
      subscribe_and_join(
        socket(OMG.WatcherRPC.Web.Socket),
        Channel.Transfer,
        TestHelper.create_topic("transfer", alice_address)
      )

    tx = OMG.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 7}, {bob, 3}])
    %{"blknum" => block_nr} = TestHelper.submit(tx)

    IntegrationTest.wait_for_block_fetch(block_nr, @timeout)

    assert [%{"blknum" => ^block_nr}] = TestHelper.get_utxos(bob.addr)

    assert [
             %{"blknum" => ^token_deposit_blknum},
             %{"blknum" => ^block_nr}
           ] = TestHelper.get_utxos(alice.addr)

    assert TestHelper.get_utxos(alice.addr) == TestHelper.get_exitable_utxos(alice.addr)

    # only checking integration of the events here, contents of events tested elsewhere
    assert_push("address_received", %{})
    assert_push("address_spent", %{})

    %{
      "utxo_pos" => utxo_pos,
      "txbytes" => txbytes,
      "proof" => proof
    } = TestHelper.get_exit_data(block_nr, 0, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => exit_eth_height}} =
      Eth.RootChainHelper.start_exit(
        utxo_pos,
        txbytes,
        proof,
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    utxo_pos = Utxo.position(block_nr, 0, 0) |> Utxo.Position.encode()

    assert {:ok, [%{exit_id: exit_id, owner: ^alice_addr, eth_height: ^exit_eth_height}]} =
             Eth.RootChain.get_standard_exits(0, exit_eth_height)

    assert {:ok, {alice_addr, @eth, 7, utxo_pos}} == Eth.RootChain.get_standard_exit(exit_id)

    # Here we're waiting for child chain and watcher to process the exits
    IntegrationTest.wait_for_exit_processing(exit_eth_height, @timeout)

    assert [%{"blknum" => ^token_deposit_blknum}] = TestHelper.get_utxos(alice.addr)
    # finally alice exits her token deposit
    %{
      "utxo_pos" => utxo_pos,
      "txbytes" => txbytes,
      "proof" => proof
    } = TestHelper.get_exit_data(token_deposit_blknum, 0, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => exit_eth_height}} =
      Eth.RootChainHelper.start_exit(
        utxo_pos,
        txbytes,
        proof,
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    IntegrationTest.wait_for_exit_processing(exit_eth_height, @timeout)
    IntegrationTest.process_exits(token, alice)
    IntegrationTest.process_exits(@eth, alice)

    assert TestHelper.get_utxos(alice.addr) == TestHelper.get_exitable_utxos(alice.addr)
    assert [] == TestHelper.get_utxos(alice.addr)
  end

  @tag fixtures: [:watcher, :test_server]
  test "hash of returned block does not match hash submitted to the root chain", %{test_server: context} do
    different_hash = <<0::256>>
    block_with_incorrect_hash = %{OMG.Block.hashed_txs_at([], 1000) | hash: different_hash}

    # from now on the child chain server is broken until end of test
    Watcher.Integration.BadChildChainServer.prepare_route_to_inject_bad_block(
      context,
      block_with_incorrect_hash,
      different_hash
    )

    {:ok, _txhash} = Eth.RootChain.submit_block(different_hash, 1, 20_000_000_000)

    # checking if both machines and humans learn about the byzantine condition
    assert capture_log(fn ->
             IntegrationTest.wait_for_byzantine_events([%Event.InvalidBlock{}.name], @timeout)
           end) =~ inspect({:error, :incorrect_hash})
  end

  @tag fixtures: [:watcher, :alice, :test_server]
  test "bad transaction with not existing utxo, detected by interactions with State", %{
    alice: alice,
    test_server: context
  } do
    # preparing block with invalid transaction
    recovered = OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}])
    block_with_incorrect_transaction = OMG.Block.hashed_txs_at([recovered], 1000)

    # from now on the child chain server is broken until end of test
    OMG.Watcher.Integration.BadChildChainServer.prepare_route_to_inject_bad_block(
      context,
      block_with_incorrect_transaction
    )

    invalid_block_hash = block_with_incorrect_transaction.hash
    {:ok, _txhash} = Eth.RootChain.submit_block(invalid_block_hash, 1, 20_000_000_000)

    # checking if both machines and humans learn about the byzantine condition
    assert capture_log(fn ->
             IntegrationTest.wait_for_byzantine_events([%Event.InvalidBlock{}.name], @timeout)
           end) =~ inspect(:tx_execution)
  end

  @tag fixtures: [:watcher, :stable_alice, :child_chain, :token, :stable_alice_deposits, :test_server]
  test "transaction which is using already spent utxo from exit and happened after margin of slow validator(m_sv) causes to emit unchallenged_exit event",
       %{stable_alice: alice, stable_alice_deposits: {deposit_blknum, _}, test_server: context} do
    tx = OMG.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
    %{"blknum" => exit_blknum} = TestHelper.submit(tx)

    # Here we're preparing invalid block
    bad_tx = OMG.TestHelper.create_recovered([{exit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
    bad_block_number = 2_000

    %{hash: bad_block_hash, number: _, transactions: _} =
      bad_block = OMG.Block.hashed_txs_at([bad_tx], bad_block_number)

    # from now on the child chain server is broken until end of test
    OMG.Watcher.Integration.BadChildChainServer.prepare_route_to_inject_bad_block(context, bad_block)

    IntegrationTest.wait_for_block_fetch(exit_blknum, @timeout)

    %{
      "txbytes" => txbytes,
      "proof" => proof,
      "utxo_pos" => utxo_pos
    } = TestHelper.get_exit_data(exit_blknum, 0, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      Eth.RootChainHelper.start_exit(
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

    # checking if both machines and humans learn about the byzantine condition
    assert capture_log(fn ->
             IntegrationTest.wait_for_byzantine_events([%Event.UnchallengedExit{}.name], @timeout)
           end) =~ inspect(:unchallenged_exit)

    # we should still be able to challenge this "unchallenged exit" - just smoke testing the endpoint, details elsewhere
    TestHelper.get_exit_challenge(exit_blknum, 0, 0)
  end

  @tag :this
  # NOTE: deposits are not per se required here, but it is a handy way to get an imported account ready
  @tag fixtures: [:watcher, :child_chain, :alice, :alice_deposits]
  test "sign transaction using typed data and signTypedData EthRPC call", %{alice: alice} do
    {:ok, alice_enc} = Crypto.encode_address(alice.addr)
    zero_int_hex = "0x0"
    zero_input = %{blknum: zero_int_hex, txindex: zero_int_hex, oindex: zero_int_hex}
    zero_output = %{owner: @zero_address_hex, currency: @zero_address_hex, amount: zero_int_hex}
    zero_32_bytes_hex = "0x0000000000000000000000000000000000000000000000000000000000000000"

    domainSpec = [
      %{name: "name", type: "string"},
      %{name: "version", type: "string"},
      %{name: "verifyingContract", type: "address"},
      %{name: "salt", type: "bytes32"},
      %{name: "chainId", type: "uint256"}
    ]

    txSpec = [
      %{name: "input0", type: "Input"},
      %{name: "input1", type: "Input"},
      %{name: "input2", type: "Input"},
      %{name: "input3", type: "Input"},
      %{name: "output0", type: "Output"},
      %{name: "output1", type: "Output"},
      %{name: "output2", type: "Output"},
      %{name: "output3", type: "Output"},
      %{name: "metadata", type: "bytes32"}
    ]

    inputSpec = [
      %{name: "blknum", type: "uint256"},
      %{name: "txindex", type: "uint256"},
      %{name: "oindex", type: "uint256"}
    ]

    outputSpec = [
      %{name: "owner", type: "address"},
      %{name: "currency", type: "address"},
      %{name: "amount", type: "uint256"}
    ]

    domainData = %{
      name: "OMG Network",
      version: "1",
      # FIXME: don't hardcode this (for now taken from /home/user/sources/elixir-omg/apps/omg/lib/omg/typed_data_hash/config.ex)
      verifyingContract: "0x7c276dcaab99bd16163c1bcce671cad6a1ec0945",
      salt: "0xfad5c7f626d80f9256ef01929f3beb96e058b8b4b0e3fe52d84f054c0e2a7a83",
      # FIXME: adding this is necessary for parity, see typed_data_hash/tools.ex
      chainId: "0x1"
    }

    test_typed_data = %{
      types: %{
        EIP712Domain: domainSpec,
        Transaction: txSpec,
        Input: inputSpec,
        Output: outputSpec
      },
      domain: domainData,
      primaryType: "Transaction",
      message: %{
        input0: zero_input,
        input1: zero_input,
        input2: zero_input,
        input3: zero_input,
        output0: zero_output,
        output1: zero_output,
        output2: zero_output,
        output3: zero_output,
        metadata: zero_32_bytes_hex
      }
    }

    pass = "ThisIsATestnetPassphrase"
    {:ok, sig_enc} = Ethereumex.HttpClient.request("personal_signTypedData", [test_typed_data, alice_enc, pass], [])
    sig = Eth.Encoding.from_hex(sig_enc)

    assert %OMG.State.Transaction.Signed{sigs: [^sig]} =
             OMG.State.Transaction.new([], [])
             |> OMG.DevCrypto.sign([alice.priv])
  end
end
