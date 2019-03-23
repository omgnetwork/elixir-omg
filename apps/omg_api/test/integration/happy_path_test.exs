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

defmodule OMG.API.Integration.HappyPathTest do
  @moduledoc """
  Tests a simple happy path of all the pieces working together
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use Plug.Test

  alias OMG.Block
  alias OMG.DevCrypto
  alias OMG.Eth
  alias OMG.Integration.DepositHelper
  alias OMG.RPC.Web.Encoding
  alias OMG.RPC.Web.TestHelper
  alias OMG.State.Transaction
  alias OMG.Utxo

  require OMG.Utxo

  @moduletag :integration
  # bumping the timeout to two minutes for the tests here, as they do a lot of transactions to Ethereum to test
  @moduletag timeout: 120_000

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @interval OMG.Eth.RootChain.get_child_block_interval() |> elem(1)

  @tag fixtures: [:alice, :bob, :omg_child_chain, :token, :alice_deposits]
  test "deposit, spend, restart, exit etc works fine", %{
    alice: alice,
    bob: bob,
    token: token,
    alice_deposits: {deposit_blknum, token_deposit_blknum}
  } do
    raw_tx = Transaction.new([{deposit_blknum, 0, 0}], [{bob.addr, @eth, 7}, {alice.addr, @eth, 3}], <<0::256>>)

    tx = raw_tx |> DevCrypto.sign([alice.priv, <<>>]) |> Transaction.Signed.encode()
    # spend the deposit
    assert {:ok, %{"blknum" => spend_child_block}} = submit_transaction(tx)

    token_raw_tx = Transaction.new([{token_deposit_blknum, 0, 0}], [{bob.addr, token, 8}, {alice.addr, token, 2}])
    token_tx = token_raw_tx |> DevCrypto.sign([alice.priv, <<>>]) |> Transaction.Signed.encode()
    # spend the token deposit
    assert {:ok, %{"blknum" => spend_token_child_block}} = submit_transaction(token_tx)

    post_spend_child_block = spend_token_child_block + @interval
    {:ok, _} = Eth.DevHelpers.wait_for_next_child_block(post_spend_child_block)

    # check if operator is propagating block with hash submitted to RootChain
    {:ok, {block_hash, _}} = Eth.RootChain.get_child_chain(spend_child_block)
    assert {:ok, %{"transactions" => transactions}} = get_block(block_hash)

    # NOTE: we are checking only the `hd` because token_tx might possibly be in the next block
    {:ok, decoded_tx_bytes} = transactions |> hd() |> Encoding.from_hex()
    assert {:ok, %{raw_tx: ^raw_tx}} = Transaction.Signed.decode(decoded_tx_bytes)

    # Restart everything to check persistance and revival.
    # NOTE: this is an integration test of the critical data persistence in the child chain
    #       See various ...PersistenceTest tests for more detailed tests of persistence behaviors
    [:omg_api, :omg_eth, :omg_db] |> Enum.each(&Application.stop/1)
    {:ok, started_apps} = Application.ensure_all_started(:omg_api)
    # sanity check, did-we restart really?
    assert Enum.member?(started_apps, :omg_api)

    # repeat spending to see if all works
    raw_tx2 = Transaction.new([{spend_child_block, 0, 0}, {spend_child_block, 0, 1}], [{alice.addr, @eth, 10}])
    tx2 = raw_tx2 |> DevCrypto.sign([bob.priv, alice.priv]) |> Transaction.Signed.encode()
    # spend the output of the first tx
    assert {:ok, %{"blknum" => spend_child_block2}} = submit_transaction(tx2)

    post_spend_child_block2 = spend_child_block2 + @interval
    {:ok, _} = Eth.DevHelpers.wait_for_next_child_block(post_spend_child_block2)

    # check if operator is propagating block with hash submitted to RootChain
    {:ok, {block_hash2, _}} = Eth.RootChain.get_child_chain(spend_child_block2)

    assert {:ok, %{"transactions" => [transaction2]}} = get_block(block_hash2)
    {:ok, decoded_tx2_bytes} = transaction2 |> Encoding.from_hex()
    assert {:ok, %{raw_tx: ^raw_tx2}} = Transaction.Signed.decode(decoded_tx2_bytes)

    # sanity checks, mainly persistence & failure responses
    assert {:ok, %{}} = get_block(block_hash)
    assert {:error, %{"code" => "get_block:not_found"}} = get_block(<<0::size(256)>>)
    assert {:error, %{"code" => "submit:utxo_not_found"}} = submit_transaction(tx)
    assert {:error, %{"code" => "submit:utxo_not_found"}} = submit_transaction(tx2)
    assert {:error, %{"code" => "submit:utxo_not_found"}} = submit_transaction(token_tx)

    # try to exit from transaction2's output
    proof = Block.inclusion_proof(%Block{transactions: [tx2]}, 0)
    encoded_utxo_pos = Utxo.position(spend_child_block2, 0, 0) |> Utxo.Position.encode()
    raw_txbytes = raw_tx2 |> Transaction.encode()

    assert {:ok, %{"status" => "0x1", "blockNumber" => exit_eth_height}} =
             Eth.RootChain.start_exit(
               encoded_utxo_pos,
               raw_txbytes,
               proof,
               alice.addr
             )
             |> Eth.DevHelpers.transact_sync!()

    # check if the utxo is no longer available
    exiters_finality_margin = Application.fetch_env!(:omg, :deposit_finality_margin) + 1
    {:ok, _} = Eth.DevHelpers.wait_for_root_chain_block(exit_eth_height + exiters_finality_margin)

    invalid_raw_tx = Transaction.new([{spend_child_block2, 0, 0}], [{alice.addr, @eth, 10}])
    invalid_tx = invalid_raw_tx |> DevCrypto.sign([alice.priv]) |> Transaction.Signed.encode()
    assert {:error, %{"code" => "submit:utxo_not_found"}} = submit_transaction(invalid_tx)
  end

  @tag fixtures: [:alice, :omg_child_chain, :alice_deposits]
  test "check that unspent funds can be exited exited with in-flight exits",
       %{alice: alice, alice_deposits: {deposit_blknum, _}} do
    # create transaction, submit, wait for block publication
    tx = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 5}, {alice, 5}])
    {:ok, %{"blknum" => blknum, "txindex" => txindex}} = tx |> Transaction.Signed.encode() |> submit_transaction()

    post_spend_child_block = blknum + @interval
    {:ok, _} = Eth.DevHelpers.wait_for_next_child_block(post_spend_child_block)

    # create transaction & data for in-flight exit, start in-flight exit
    %Transaction.Signed{
      raw_tx: raw_in_flight_tx,
      sigs: in_flight_tx_sigs
    } = OMG.TestHelper.create_signed([{blknum, txindex, 0, alice}, {blknum, txindex, 1, alice}], @eth, [{alice, 10}])

    proof = Block.inclusion_proof(%Block{transactions: [Transaction.Signed.encode(tx)]}, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      Eth.RootChain.in_flight_exit(
        raw_in_flight_tx |> Transaction.encode(),
        get_input_txs([tx, tx]),
        proof <> proof,
        Enum.join(in_flight_tx_sigs),
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    exiters_finality_margin = Application.fetch_env!(:omg, :deposit_finality_margin) + 1
    Eth.DevHelpers.wait_for_root_chain_block(eth_height + exiters_finality_margin)

    # check that output of 1st transaction was spend by in-flight exit
    tx_double_spend = OMG.TestHelper.create_encoded([{blknum, txindex, 0, alice}], @eth, [{alice, 2}, {alice, 3}])
    assert {:error, %{"code" => "submit:utxo_not_found"}} = submit_transaction(tx_double_spend)

    deposit_blknum = DepositHelper.deposit_to_child_chain(alice.addr, 10)

    %Transaction.Signed{raw_tx: raw_tx, sigs: sigs} =
      tx = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 7}, {alice, 3}])

    {:ok, %{"blknum" => blknum}} = submit_transaction(tx |> Transaction.Signed.encode())

    in_flight_tx = raw_tx |> Transaction.encode()

    # create exit data for tx spending deposit & start in-flight exit
    deposit_tx = OMG.TestHelper.create_signed([], @eth, [{alice, 10}])

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      Eth.RootChain.in_flight_exit(
        in_flight_tx,
        get_input_txs([deposit_tx]),
        Block.inclusion_proof(%Block{transactions: [Transaction.Signed.encode(deposit_tx)]}, 0),
        Enum.join(sigs),
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    Eth.DevHelpers.wait_for_root_chain_block(eth_height + exiters_finality_margin)

    # piggyback only to the first transaction's output & wait for finalization
    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      Eth.RootChain.piggyback_in_flight_exit(in_flight_tx, 4, alice.addr)
      |> Eth.DevHelpers.transact_sync!()

    Eth.DevHelpers.wait_for_root_chain_block(eth_height + exiters_finality_margin)

    # check that deposit & 1st, piggybacked output are spent, 2nd output is not
    deposit_double_spend =
      OMG.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 7}, {alice, 3}])

    assert {:error, %{"code" => "submit:utxo_not_found"}} = submit_transaction(deposit_double_spend)

    first_output_double_spend = OMG.TestHelper.create_encoded([{blknum, 0, 0, alice}], @eth, [{alice, 7}])
    assert {:error, %{"code" => "submit:utxo_not_found"}} = submit_transaction(first_output_double_spend)

    second_output_spend = OMG.TestHelper.create_encoded([{blknum, 0, 1, alice}], @eth, [{alice, 3}])
    assert {:ok, _} = submit_transaction(second_output_spend)
  end

  defp submit_transaction(tx) do
    TestHelper.rpc_call(:post, "/transaction.submit", %{transaction: Encoding.to_hex(tx)})
    |> get_body_data()
  end

  defp get_block(hash) do
    TestHelper.rpc_call(:post, "/block.get", %{hash: Encoding.to_hex(hash)})
    |> get_body_data()
  end

  defp get_body_data(resp_body) do
    {
      if(resp_body["success"], do: :ok, else: :error),
      resp_body["data"]
    }
  end

  defp get_input_txs(txs) do
    txs
    |> Enum.map(fn %Transaction.Signed{raw_tx: raw_tx} ->
      raw_tx |> Transaction.encode() |> ExRLP.decode()
    end)
    |> ExRLP.encode()
  end
end
