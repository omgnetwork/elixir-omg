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
  alias OMG.JSONRPC.Client
  alias OMG.Watcher.Eventer.Event
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest
  alias OMG.Watcher.TestHelper
  alias OMG.Watcher.Web.Channel

  import ExUnit.CaptureLog

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
    {:ok, %{blknum: block_nr}} = Client.call(:submit, %{transaction: tx})

    IntegrationTest.wait_until_block_getter_fetches_block(block_nr, @timeout)

    encode_tx = Client.encode(tx)

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
      Client.encode(%Event.AddressReceived{
        tx: recovered_tx,
        child_blknum: block_nr,
        child_block_hash: block_hash,
        submited_at_ethheight: event_eth_height
      })

    address_spent_event =
      Client.encode(%Event.AddressSpent{
        tx: recovered_tx,
        child_blknum: block_nr,
        child_block_hash: block_hash,
        submited_at_ethheight: event_eth_height
      })

    assert_push("address_received", ^address_received_event)

    assert_push("address_spent", ^address_spent_event)

    %{
      "utxo_pos" => utxo_pos,
      "txbytes" => txbytes,
      "proof" => proof,
      "sigs" => sigs
    } = IntegrationTest.get_exit_data(block_nr, 0, 0)

    {:ok, txhash} =
      Eth.RootChain.start_exit(
        utxo_pos,
        txbytes,
        proof,
        sigs,
        alice.addr
      )

    {:ok, %{"status" => "0x1"}} = Eth.WaitFor.eth_receipt(txhash, @timeout)

    {:ok, height} = Eth.get_ethereum_height()

    utxo_pos = Utxo.position(block_nr, 0, 0) |> Utxo.Position.encode()

    assert {:ok, [%{amount: 7, utxo_pos: utxo_pos, owner: alice.addr, currency: @eth}]} ==
             Eth.RootChain.get_exits(0, height)

    # exiting spends UTXO on child chain
    # wait until the exit is recognized and attempt to spend the exited utxo
    Process.sleep(4_000)
    tx2 = API.TestHelper.create_encoded([{block_nr, 0, 0, alice}], @eth, [{alice, 7}])

    {:error, {-32_603, "Internal error", "utxo_not_found"}} = Client.call(:submit, %{transaction: tx2})
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
    {:ok, %{blknum: spend_token_child_block}} = Client.call(:submit, %{transaction: token_tx})

    IntegrationTest.wait_until_block_getter_fetches_block(spend_token_child_block, @timeout)

    %{
      "txbytes" => txbytes,
      "proof" => proof,
      "sigs" => sigs,
      "utxo_pos" => utxo_pos
    } = IntegrationTest.get_exit_data(spend_token_child_block, 0, 0)

    {:ok, txhash} =
      Eth.RootChain.start_exit(
        utxo_pos,
        txbytes,
        proof,
        sigs,
        alice.addr
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

    {:ok, _, _socket} = subscribe_and_join(socket(), Channel.Byzantine, "byzantine")

    JSONRPC2.Servers.HTTP.http(BadChildChainHash, port: Application.get_env(:omg_jsonrpc, :omg_api_rpc_port))

    assert capture_log(fn ->
             {:ok, _txhash} = Eth.RootChain.submit_block(BadChildChainHash.different_hash(), 1, 20_000_000_000)

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

    {:ok, _, _socket} = subscribe_and_join(socket(), Channel.Byzantine, "byzantine")

    JSONRPC2.Servers.HTTP.http(
      BadChildChainTransaction,
      port: Application.get_env(:omg_jsonrpc, :omg_api_rpc_port)
    )

    %API.Block{hash: hash} = BadChildChainTransaction.block_with_incorrect_transaction()

    assert capture_log(fn ->
             {:ok, _txhash} = Eth.RootChain.submit_block(hash, 1, 20_000_000_000)

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

  @tag fixtures: [:watcher_sandbox, :stable_alice, :child_chain, :token, :stable_alice_deposits]
  test "transaction which is using already spent utxo from exit and happened after margin of slow validator(m_sv) causes to emit invalid_block event",
       %{stable_alice: alice, stable_alice_deposits: {deposit_blknum, _}} do
    margin_slow_validator =
      Application.get_env(:omg_watcher, :margin_slow_validator) * Application.get_env(:omg_eth, :child_block_interval)

    # TODO remove this tx , use directly deposit_blknum to get_exit_data
    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
    {:ok, %{blknum: exit_blknum}} = Client.call(:submit, %{transaction: tx})

    # Here we calcualted bad_block_number by adding `exit_blknum` and 2 * `margin_slow_validator`
    # to have guarantee that bad_block_number will be after margoin of slow validator(m_sv)
    bad_block_number = exit_blknum + margin_slow_validator * 2
    bad_tx = API.TestHelper.create_recovered([{exit_blknum, 0, 0, alice}], @eth, [{alice, 10}])

    %{hash: bad_block_hash, number: _, transactions: _} =
      bad_block = API.Block.hashed_txs_at([bad_tx], bad_block_number)

    # Here we manually submiting invalid block with big/future nonce to the Rootchain to make
    # the Rootchain to mine invalid block instead of block submitted by child chain
    {:ok, child_block_interval} = Eth.RootChain.get_child_block_interval()
    nonce = div(bad_block_number, child_block_interval)
    {:ok, _} = OMG.Eth.RootChain.submit_block(bad_block_hash, nonce, 1)

    {:module, BadChildChainBLock, _, _} = OMG.Watcher.Integration.BadChildChainBLock.create_module(bad_block)

    JSONRPC2.Servers.HTTP.http(BadChildChainBLock, port: BadChildChainBLock.port())

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

    {:ok, %{"status" => "0x1"}} = Eth.WaitFor.eth_receipt(txhash, @timeout)

    Application.put_env(
      :omg_jsonrpc,
      :child_chain_url,
      "http://localhost:" <> Integer.to_string(BadChildChainBLock.port())
    )

    assert capture_log(fn ->
             assert_block_getter_down()
           end) =~ inspect(:tx_execution)

    invalid_block_event =
      Client.encode(%Event.InvalidBlock{
        error_type: :tx_execution,
        hash: bad_block_hash,
        number: bad_block_number
      })

    assert_push("invalid_block", ^invalid_block_event)

    JSONRPC2.Servers.HTTP.shutdown(BadChildChainBLock)

    Application.put_env(:omg_jsonrpc, :child_chain_url, "http://localhost:9656")
  end

  defp assert_block_getter_down do
    :ok = TestHelper.wait_for_process(Process.whereis(OMG.Watcher.BlockGetter))
  end
end
