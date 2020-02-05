# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule OMG.ChildChain.Integration.HappyPathTest do
  @moduledoc """
  Tests a simple happy path of all the pieces working together
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use Plug.Test

  alias OMG.Block
  alias OMG.ChildChainRPC.Web.TestHelper
  alias OMG.Configuration
  alias OMG.Eth
  alias OMG.State.Transaction
  alias OMG.Status.Alert.Alarm
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.Utxo
  alias Support.DevHelper
  alias Support.Integration.DepositHelper
  alias Support.RootChainHelper
  require OMG.Utxo

  @moduletag :integration
  @moduletag :child_chain
  # bumping the timeout to two minutes for the tests here, as they do a lot of transactions to Ethereum to test
  @moduletag timeout: 120_000

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @interval OMG.Eth.RootChain.get_child_block_interval() |> elem(1)
  # kill this test ASAP
  @tag fixtures: [:alice, :bob, :in_beam_child_chain, :token, :alice_deposits]
  test "deposit, spend, restart, exit etc works fine", %{
    alice: alice,
    bob: bob,
    token: token,
    alice_deposits: {deposit_blknum, token_deposit_blknum}
  } do
    raw_tx = Transaction.Payment.new([{deposit_blknum, 0, 0}], [{bob.addr, @eth, 7}, {alice.addr, @eth, 2}], <<0::256>>)

    tx = OMG.TestHelper.sign_encode(raw_tx, [alice.priv])
    # spend the deposit
    assert {:ok, %{"blknum" => spend_child_block}} = submit_transaction(tx)

    token_raw_tx =
      Transaction.Payment.new([{token_deposit_blknum, 0, 0}], [{bob.addr, token, 6}, {alice.addr, token, 2}])

    token_tx = OMG.TestHelper.sign_encode(token_raw_tx, [alice.priv])
    # spend the token deposit
    assert {:ok, %{"blknum" => spend_token_child_block}} = submit_transaction(token_tx)

    post_spend_child_block = spend_token_child_block + @interval
    {:ok, _} = DevHelper.wait_for_next_child_block(post_spend_child_block)

    # check if operator is propagating block with hash submitted to RootChain
    {:ok, {block_hash, _}} = Eth.RootChain.get_child_chain(spend_child_block)
    assert {:ok, %{"transactions" => transactions}} = get_block(block_hash)

    # NOTE: we are checking only the `hd` because token_tx might possibly be in the next block
    {:ok, decoded_tx_bytes} = transactions |> hd() |> Encoding.from_hex()
    assert %{raw_tx: ^raw_tx} = Transaction.Signed.decode!(decoded_tx_bytes)

    # Restart everything to check persistance and revival.
    # NOTE: this is an integration test of the critical data persistence in the child chain
    #       See various ...PersistenceTest tests for more detailed tests of persistence behaviors
    Enum.each([:omg_child_chain, :omg_eth, :omg_db], &Application.stop/1)
    {:ok, _started_apps} = Application.ensure_all_started(:omg_child_chain)
    wait_for_web()
    # repeat spending to see if all works
    raw_tx2 = Transaction.Payment.new([{spend_child_block, 0, 0}, {spend_child_block, 0, 1}], [{alice.addr, @eth, 8}])
    tx2 = OMG.TestHelper.sign_encode(raw_tx2, [bob.priv, alice.priv])
    # spend the output of the first tx
    assert {:ok, %{"blknum" => spend_child_block2}} = submit_transaction(tx2)

    post_spend_child_block2 = spend_child_block2 + @interval
    {:ok, _} = DevHelper.wait_for_next_child_block(post_spend_child_block2)

    # check if operator is propagating block with hash submitted to RootChain
    {:ok, {block_hash2, _}} = Eth.RootChain.get_child_chain(spend_child_block2)

    assert {:ok, %{"transactions" => [transaction2, fee_tx_hex]}} = get_block(block_hash2)
    {:ok, decoded_tx2_bytes} = Encoding.from_hex(transaction2)
    assert %{raw_tx: ^raw_tx2} = Transaction.Signed.decode!(decoded_tx2_bytes)

    # sanity checks, mainly persistence & failure responses
    assert {:ok, %{}} = get_block(block_hash)
    assert {:error, %{"code" => "get_block:not_found"}} = get_block(<<0::size(256)>>)
    assert {:error, %{"code" => "submit:utxo_not_found"}} = submit_transaction(tx)
    assert {:error, %{"code" => "submit:utxo_not_found"}} = submit_transaction(tx2)
    assert {:error, %{"code" => "submit:utxo_not_found"}} = submit_transaction(token_tx)

    # try to exit from transaction2's output
    {:ok, fee_bytes} = Encoding.from_hex(fee_tx_hex)
    proof = Block.inclusion_proof([tx2, fee_bytes], 0)
    encoded_utxo_pos = Utxo.Position.encode(Utxo.position(spend_child_block2, 0, 0))
    raw_txbytes = Transaction.raw_txbytes(raw_tx2)

    assert {:ok, %{"status" => "0x1", "blockNumber" => exit_eth_height}} =
             DevHelper.transact_sync!(
               RootChainHelper.start_exit(
                 encoded_utxo_pos,
                 raw_txbytes,
                 proof,
                 alice.addr
               )
             )

    # check if the utxo is no longer available
    exiters_finality_margin = Configuration.deposit_finality_margin() + 1
    {:ok, _} = DevHelper.wait_for_root_chain_block(exit_eth_height + exiters_finality_margin)

    invalid_raw_tx = Transaction.Payment.new([{spend_child_block2, 0, 0}], [{alice.addr, @eth, 10}])
    invalid_tx = OMG.TestHelper.sign_encode(invalid_raw_tx, [alice.priv])
    assert {:error, %{"code" => "submit:utxo_not_found"}} = submit_transaction(invalid_tx)
  end

  @tag fixtures: [:alice, :in_beam_child_chain, :alice_deposits]
  test "check that unspent funds can be exited with in-flight exits",
       %{alice: alice, alice_deposits: {deposit_blknum, _}} do
    # create transaction, submit, wait for block publication
    tx = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 5}, {alice, 4}])
    {:ok, %{"blknum" => blknum, "txindex" => txindex}} = tx |> Transaction.Signed.encode() |> submit_transaction()

    post_spend_child_block = blknum + @interval
    {:ok, _} = DevHelper.wait_for_next_child_block(post_spend_child_block)

    # create transaction & data for in-flight exit, start in-flight exit
    %Transaction.Signed{sigs: in_flight_tx_sigs} =
      in_flight_tx =
      OMG.TestHelper.create_signed([{blknum, txindex, 0, alice}, {blknum, txindex, 1, alice}], @eth, [{alice, 8}])

    fee_claimer = Application.fetch_env!(:omg, :fee_claimer_address)
    fee_tx = OMG.TestHelper.create_encoded_fee_tx(blknum, fee_claimer, @eth, 1)

    proof = Block.inclusion_proof([Transaction.Signed.encode(tx), fee_tx], txindex)

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      RootChainHelper.in_flight_exit(
        Transaction.raw_txbytes(in_flight_tx),
        get_input_txs([tx, tx]),
        [
          Utxo.Position.encode(Utxo.position(blknum, txindex, 0)),
          Utxo.Position.encode(Utxo.position(blknum, txindex, 1))
        ],
        [proof, proof],
        in_flight_tx_sigs,
        alice.addr
      )
      |> DevHelper.transact_sync!()

    exiters_finality_margin = Configuration.deposit_finality_margin() + 1
    DevHelper.wait_for_root_chain_block(eth_height + exiters_finality_margin)

    # check that output of 1st transaction was spend by in-flight exit
    tx_double_spend = OMG.TestHelper.create_encoded([{blknum, txindex, 0, alice}], @eth, [{alice, 2}, {alice, 3}])
    assert {:error, %{"code" => "submit:utxo_not_found"}} = submit_transaction(tx_double_spend)

    deposit_blknum = DepositHelper.deposit_to_child_chain(alice.addr, 10)

    %Transaction.Signed{sigs: sigs} =
      in_flight_tx2 = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 6}, {alice, 3}])

    {:ok, %{"blknum" => blknum}} = in_flight_tx2 |> Transaction.Signed.encode() |> submit_transaction()

    in_flight_tx2_rawbytes = Transaction.raw_txbytes(in_flight_tx2)

    # create exit data for tx spending deposit & start in-flight exit
    deposit_tx = OMG.TestHelper.create_signed([], @eth, [{alice, 10}])
    proof = Block.inclusion_proof([Transaction.Signed.encode(deposit_tx)], 0)

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      RootChainHelper.in_flight_exit(
        in_flight_tx2_rawbytes,
        get_input_txs([deposit_tx]),
        [Utxo.Position.encode(Utxo.position(deposit_blknum, 0, 0))],
        [proof],
        sigs,
        alice.addr
      )
      |> DevHelper.transact_sync!()

    DevHelper.wait_for_root_chain_block(eth_height + exiters_finality_margin)

    # piggyback only to the first transaction's output & wait for finalization
    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      RootChainHelper.piggyback_in_flight_exit_on_output(in_flight_tx2_rawbytes, 0, alice.addr)
      |> DevHelper.transact_sync!()

    DevHelper.wait_for_root_chain_block(eth_height + exiters_finality_margin)

    # check that deposit & 1st, piggybacked output are spent, 2nd output is not
    deposit_double_spend =
      OMG.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 7}, {alice, 3}])

    assert {:error, %{"code" => "submit:utxo_not_found"}} = submit_transaction(deposit_double_spend)

    first_output_double_spend = OMG.TestHelper.create_encoded([{blknum, 0, 0, alice}], @eth, [{alice, 7}])
    assert {:error, %{"code" => "submit:utxo_not_found"}} = submit_transaction(first_output_double_spend)

    second_output_spend = OMG.TestHelper.create_encoded([{blknum, 0, 1, alice}], @eth, [{alice, 2}])
    assert {:ok, _} = submit_transaction(second_output_spend)
  end

  @tag fixtures: [:alice, :in_beam_child_chain, :alice_deposits]
  test "check in-flight exit input piggybacking is ignored by the child chain",
       %{alice: alice, alice_deposits: {deposit_blknum, _}} do
    # create transaction, submit, wait for block publication
    tx = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 9}])
    {:ok, %{"blknum" => blknum, "txindex" => txindex}} = tx |> Transaction.Signed.encode() |> submit_transaction()

    %Transaction.Signed{sigs: in_flight_tx_sigs} =
      in_flight_tx = OMG.TestHelper.create_signed([{blknum, txindex, 0, alice}], @eth, [{alice, 5}])

    # We need to consider fee tx in block, as 10 ETH deposited = 9 transferred with `tx` + 1 collected as fees
    fee_claimer = Application.fetch_env!(:omg, :fee_claimer_address)
    fee_tx = OMG.TestHelper.create_encoded_fee_tx(blknum, fee_claimer, @eth, 1)

    proof = Block.inclusion_proof([Transaction.Signed.encode(tx), fee_tx], 0)

    {:ok, %{"status" => "0x1"}} =
      RootChainHelper.in_flight_exit(
        Transaction.raw_txbytes(in_flight_tx),
        get_input_txs([tx]),
        [Utxo.Position.encode(Utxo.position(blknum, txindex, 0))],
        [proof],
        in_flight_tx_sigs,
        alice.addr
      )
      |> DevHelper.transact_sync!()

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      in_flight_tx
      |> Transaction.raw_txbytes()
      |> RootChainHelper.piggyback_in_flight_exit_on_input(0, alice.addr)
      |> DevHelper.transact_sync!()

    exiters_finality_margin = Configuration.deposit_finality_margin() + 1
    DevHelper.wait_for_root_chain_block(eth_height + exiters_finality_margin)
    # sanity check everything still lives
    assert {:error, %{"code" => "submit:utxo_not_found"}} = tx |> Transaction.Signed.encode() |> submit_transaction()
  end

  @tag fixtures: [:alice, :in_beam_child_chain]
  test "check submitted fee transaction is rejected", %{alice: alice} do
    fee_tx = OMG.TestHelper.create_encoded_fee_tx(1000, alice.addr, @eth, 1000)

    assert {:error, %{"code" => "submit:transaction_not_supported"}} = submit_transaction(fee_tx)
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

  defp get_input_txs(txs), do: Enum.map(txs, &Transaction.raw_txbytes/1)

  defp wait_for_web(), do: wait_for_web(100)

  defp wait_for_web(counter) do
    case Keyword.has_key?(Alarm.all(), elem(Alarm.main_supervisor_halted(__MODULE__), 0)) do
      true ->
        Process.sleep(100)
        wait_for_web(counter - 1)

      false ->
        :ok
    end
  end
end
