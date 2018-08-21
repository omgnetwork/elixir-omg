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

defmodule OMGWatcher.BlockGetterTest do
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
  alias OMG.JSONRPC.Client
  alias OMGWatcher.Eventer.Event
  alias OMGWatcher.Integration
  alias OMGWatcher.TestHelper
  alias OMGWatcherWeb.ByzantineChannel
  alias OMGWatcherWeb.TransferChannel

  import ExUnit.CaptureLog

  @moduletag :integration

  @timeout 20_000
  @eth Crypto.zero_address()
  @eth_hex String.duplicate("00", 20)

  @endpoint OMGWatcherWeb.Endpoint

  @tag fixtures: [:watcher_sandbox, :child_chain, :alice, :bob, :alice_deposits]
  test "get the blocks from child chain after transaction and start exit", %{
    alice: alice,
    bob: bob,
    alice_deposits: {deposit_blknum, _}
  } do
    {:ok, alice_address} = Crypto.encode_address(alice.addr)

    {:ok, _, _socket} =
      subscribe_and_join(socket(), TransferChannel, TestHelper.create_topic("transfer", alice_address))

    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 7}, {bob, 3}])
    {:ok, %{blknum: block_nr}} = Client.call(:submit, %{transaction: tx})

    Integration.TestHelper.wait_until_block_getter_fetches_block(block_nr, @timeout)

    encode_tx = Client.encode(tx)

    assert [
             %{
               "currency" => @eth_hex,
               "amount" => 3,
               "blknum" => block_nr,
               "oindex" => 0,
               "txindex" => 0,
               "txbytes" => encode_tx
             }
           ] == get_utxo(bob)

    assert [
             %{
               "currency" => @eth_hex,
               "amount" => 7,
               "blknum" => block_nr,
               "oindex" => 0,
               "txindex" => 0,
               "txbytes" => encode_tx
             }
           ] == get_utxo(alice)

    {:ok, recovered_tx} = API.Core.recover_tx(tx)
    {:ok, {block_hash, _}} = Eth.get_child_chain(block_nr)

    # TODO: this is turned off now and set to zero. Rethink test after this gets fixed (possibly test differently)
    eth_height = 0

    address_received_event =
      Client.encode(%Event.AddressReceived{
        tx: recovered_tx,
        child_blknum: block_nr,
        child_block_hash: block_hash,
        submited_at_ethheight: eth_height
      })

    address_spent_event =
      Client.encode(%Event.AddressSpent{
        tx: recovered_tx,
        child_blknum: block_nr,
        child_block_hash: block_hash,
        submited_at_ethheight: eth_height
      })

    assert_push("address_received", ^address_received_event)

    assert_push("address_spent", ^address_spent_event)

    %{
      utxo_pos: utxo_pos,
      txbytes: txbytes,
      proof: proof,
      sigs: sigs
    } = Integration.TestHelper.compose_utxo_exit(block_nr, 0, 0)

    {:ok, txhash} =
      Eth.start_exit(
        utxo_pos,
        txbytes,
        proof,
        sigs,
        1,
        alice_address
      )

    {:ok, %{"status" => "0x1"}} = Eth.WaitFor.eth_receipt(txhash, @timeout)

    {:ok, height} = Eth.get_ethereum_height()

    utxo_pos = Utxo.position(block_nr, 0, 0) |> Utxo.Position.encode()

    assert {:ok, [%{amount: 7, utxo_pos: utxo_pos, owner: alice_address, token: @eth}]} == Eth.get_exits(0, height)

    # exiting spends UTXO on child chain
    # wait until the exit is recognized and attempt to spend the exited utxo
    Process.sleep(1_000)
    tx2 = API.TestHelper.create_encoded([{block_nr, 0, 0, alice}], @eth, [{alice, 7}])
    {:error, {-32_603, "Internal error", "utxo_not_found"}} = Client.call(:submit, %{transaction: tx2})
  end

  @tag fixtures: [:watcher_sandbox, :token, :child_chain, :alice, :alice_deposits]
  test "exit erc20, without challenging an invalid exit", %{
    token: token,
    alice: alice,
    alice_deposits: {_, token_deposit_blknum}
  } do
    {:ok, alice_address} = Crypto.encode_address(alice.addr)
    {:ok, currency} = API.Crypto.decode_address(token.address)

    token_tx = API.TestHelper.create_encoded([{token_deposit_blknum, 0, 0, alice}], currency, [{alice, 10}])

    # spend the token deposit
    {:ok, %{blknum: spend_token_child_block}} = Client.call(:submit, %{transaction: token_tx})

    Integration.TestHelper.wait_until_block_getter_fetches_block(spend_token_child_block, @timeout)

    %{
      txbytes: txbytes,
      proof: proof,
      sigs: sigs,
      utxo_pos: utxo_pos
    } = Integration.TestHelper.compose_utxo_exit(spend_token_child_block, 0, 0)

    {:ok, txhash} =
      Eth.start_exit(
        utxo_pos,
        txbytes,
        proof,
        sigs,
        1,
        alice_address
      )

    {:ok, %{"status" => "0x1"}} = Eth.WaitFor.eth_receipt(txhash, @timeout)
  end

  @tag fixtures: [:watcher_sandbox, :alice]
  test "diffrent hash send by child chain", %{alice: alice} do
    defmodule BadChildChainHash do
      use JSONRPC2.Server.Handler

      def empty_block, do: [] |> API.Block.hashed_txs_at(1000)
      def different_hash, do: <<0::256>>

      def handle_request(_, _) do
        Client.encode(%API.Block{empty_block() | hash: different_hash()})
      end
    end

    {:ok, _, _socket} = subscribe_and_join(socket(), ByzantineChannel, "byzantine")

    JSONRPC2.Servers.HTTP.http(BadChildChainHash, port: Application.get_env(:omg_jsonrpc, :omg_api_rpc_port))

    assert capture_log(fn ->
             {:ok, _txhash} =
               Eth.submit_block(%Eth.BlockSubmission{
                 num: 1000,
                 hash: BadChildChainHash.different_hash(),
                 nonce: 1,
                 gas_price: 20_000_000_000
               })

             assert_block_getter_down()
           end) =~ inspect(:incorrect_hash)

    invalid_block_event =
      Client.encode(%Event.InvalidBlock{
        error_type: :incorrect_hash,
        hash: BadChildChainHash.different_hash(),
        number: 1000
      })

    assert_push("invalid_block", ^invalid_block_event)

    JSONRPC2.Servers.HTTP.shutdown(BadChildChainHash)
  end

  @tag fixtures: [:watcher_sandbox]
  test "bad transaction with not existing utxo, detected by interactions with State" do
    defmodule BadChildChainTransaction do
      use JSONRPC2.Server.Handler

      # using module attribute to have a stable alice (we can't use fixtures, because modules don't see the parent
      @alice API.TestHelper.generate_entity()

      def block_with_incorrect_transaction do
        alice = @alice

        recovered = API.TestHelper.create_recovered([{1, 0, 0, alice}], Crypto.zero_address(), [{alice, 10}])

        API.Block.hashed_txs_at([recovered], 1000)
      end

      def handle_request(_, _) do
        Client.encode(block_with_incorrect_transaction())
      end
    end

    {:ok, _, _socket} = subscribe_and_join(socket(), ByzantineChannel, "byzantine")

    JSONRPC2.Servers.HTTP.http(
      BadChildChainTransaction,
      port: Application.get_env(:omg_jsonrpc, :omg_api_rpc_port)
    )

    %API.Block{hash: hash} = BadChildChainTransaction.block_with_incorrect_transaction()

    assert capture_log(fn ->
             {:ok, _txhash} =
               Eth.submit_block(%Eth.BlockSubmission{
                 num: 1_000,
                 hash: hash,
                 nonce: 1,
                 gas_price: 20_000_000_000
               })

             assert_block_getter_down()
           end) =~ inspect(:tx_execution)

    invalid_block_event =
      Client.encode(%Event.InvalidBlock{
        error_type: :tx_execution,
        hash: hash,
        number: 1000
      })

    assert_push("invalid_block", ^invalid_block_event)

    JSONRPC2.Servers.HTTP.shutdown(BadChildChainTransaction)
  end

  defp assert_block_getter_down do
    :ok = TestHelper.wait_for_process(Process.whereis(OMGWatcher.BlockGetter))
  end

  defp get_utxo(%{addr: address}) do
    {:ok, address_encode} = Crypto.encode_address(address)
    decoded_resp = TestHelper.rest_call(:get, "account/utxo?address=#{address_encode}")
    decoded_resp["utxos"]
  end
end
