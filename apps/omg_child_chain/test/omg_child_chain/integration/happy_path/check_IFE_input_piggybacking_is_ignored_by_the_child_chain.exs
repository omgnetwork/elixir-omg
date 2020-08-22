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
