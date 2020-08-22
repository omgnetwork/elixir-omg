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

  require OMG.Utxo

  alias OMG.Block
  alias OMG.ChildChainRPC.Web.TestHelper
  alias OMG.Eth.Configuration
  alias OMG.Eth.RootChain
  alias OMG.State.Transaction
  alias OMG.Status.Alert.Alarm
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.Utxo
  alias Support.DevHelper
  alias Support.Integration.DepositHelper
  alias Support.RootChainHelper

  @moduletag :needs_childchain_running
  # bumping the timeout to two minutes for the tests here, as they do a lot of transactions to Ethereum to test
  @moduletag timeout: 120_000

  @eth OMG.Eth.zero_address()
  @interval Configuration.child_block_interval()

  @tag fixtures: [:alice, :alice_deposits]
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

    fee_claimer = OMG.Configuration.fee_claimer_address()
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

    exiters_finality_margin = OMG.Configuration.deposit_finality_margin() + 1
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
    fee_claimer = OMG.Configuration.fee_claimer_address()
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

    exiters_finality_margin = OMG.Configuration.deposit_finality_margin() + 1
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
    :post
    |> TestHelper.rpc_call("/transaction.submit", %{transaction: Encoding.to_hex(tx)})
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
