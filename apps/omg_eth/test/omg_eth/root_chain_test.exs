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

defmodule OMG.Eth.RootChainTest do
  use ExUnit.Case, async: false

  alias OMG.Eth.Configuration
  alias OMG.Eth.Encoding
  alias OMG.Eth.RootChain
  alias OMG.Eth.RootChain.Abi
  alias Support.DevHelper
  alias Support.RootChainHelper

  @eth "0x0000000000000000000000000000000000000000"
  @moduletag :common

  setup do
    {:ok, exit_fn} = Support.DevNode.start()

    on_exit(exit_fn)
    :ok
  end

  test "get_root_deployment_height/2 returns current block number" do
    {:ok, number} = RootChain.get_root_deployment_height()
    assert is_integer(number)
  end

  describe "get_standard_exit_structs/2" do
    test "returns a list of standard exits by the given exit ids" do
      authority_address = Configuration.authority_address()
      {:ok, true} = Ethereumex.HttpClient.request("personal_unlockAccount", [authority_address, "", 0], [])

      # Make 3 deposits so we can do 3 exits. 1 exit will not be queried, so we can check for false positives
      _ = add_queue(authority_address)
      {utxo_pos_1, exit_1} = deposit_then_start_exit(authority_address, 1, @eth)
      {utxo_pos_2, _exit_2} = deposit_then_start_exit(authority_address, 2, @eth)
      {utxo_pos_3, exit_3} = deposit_then_start_exit(authority_address, 3, @eth)

      # Now get the exits by their ids and asserts the result
      exit_id_1 = exit_id_from_receipt(exit_1)
      exit_id_3 = exit_id_from_receipt(exit_3)

      {:ok, exits} = RootChain.get_standard_exit_structs([exit_id_1, exit_id_3])

      assert length(exits) == 2
      assert Enum.any?(exits, fn e -> elem(e, 1) == utxo_pos_1 end)
      refute Enum.any?(exits, fn e -> elem(e, 1) == utxo_pos_2 end)
      assert Enum.any?(exits, fn e -> elem(e, 1) == utxo_pos_3 end)
    end
  end

  defp deposit_then_start_exit(owner, amount, currency) do
    owner = Encoding.from_hex(owner)

    output_data = %{amount: amount, token: currency, output_guard: owner}
    deposit_utxo = %ExPlasma.Output{output_data: output_data, output_type: 1}
    deposit = %ExPlasma.Transaction{inputs: [], outputs: [deposit_utxo], tx_type: 1}

    rlp = ExPlasma.Transaction.encode(deposit)

    {:ok, deposit_tx} =
      rlp
      |> RootChainHelper.deposit(amount, owner)
      |> DevHelper.transact_sync!()

    deposit_txlog = hd(deposit_tx["logs"])
    deposit_blknum = RootChainHelper.deposit_blknum_from_receipt(deposit_tx)
    deposit_txindex = OMG.Eth.Encoding.int_from_hex(deposit_txlog["transactionIndex"])

    utxo_pos = ExPlasma.Output.Position.pos(%{blknum: deposit_blknum, txindex: deposit_txindex, oindex: 0})
    proof = ExPlasma.Encoding.merkle_proof([rlp], 0)

    {:ok, start_exit_tx} =
      utxo_pos
      |> RootChainHelper.start_exit(rlp, proof, owner)
      |> DevHelper.transact_sync!()

    {utxo_pos, start_exit_tx}
  end

  defp exit_id_from_receipt(%{"logs" => logs}) do
    topic =
      "ExitStarted(address,uint160)"
      |> ExthCrypto.Hash.hash(ExthCrypto.Hash.kec())
      |> Encoding.to_hex()

    [%{exit_id: exit_id}] =
      logs
      |> Enum.filter(&(topic in &1["topics"]))
      |> Enum.map(fn log ->
        Abi.decode_log(log)
      end)

    exit_id
  end

  defp add_queue(authority_address) do
    {:ok, true} = Ethereumex.HttpClient.request("personal_unlockAccount", [authority_address, "", 0], [])

    add_exit_queue = RootChainHelper.add_exit_queue(1, "0x0000000000000000000000000000000000000000")

    {:ok, %{"status" => "0x1"}} = Support.DevHelper.transact_sync!(add_exit_queue)
  end
end
