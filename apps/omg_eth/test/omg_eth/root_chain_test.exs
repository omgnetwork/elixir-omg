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
  alias OMG.Eth.Encoding
  alias OMG.Eth.RootChain
  alias OMG.Eth.RootChain.Abi
  alias Support.DevHelper
  alias Support.RootChainHelper
  alias Support.SnapshotContracts

  use ExUnit.Case, async: false

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @moduletag :common

  setup do
    {:ok, exit_fn} = Support.DevNode.start()
    data = SnapshotContracts.parse_contracts()

    contracts = %{
      authority_address: Encoding.from_hex(data["AUTHORITY_ADDRESS"]),
      plasma_framework_tx_hash: Encoding.from_hex(data["TXHASH_CONTRACT"]),
      erc20_vault: Encoding.from_hex(data["CONTRACT_ADDRESS_ERC20_VAULT"]),
      eth_vault: Encoding.from_hex(data["CONTRACT_ADDRESS_ETH_VAULT"]),
      payment_exit_game: Encoding.from_hex(data["CONTRACT_ADDRESS_PAYMENT_EXIT_GAME"]),
      plasma_framework: Encoding.from_hex(data["CONTRACT_ADDRESS_PLASMA_FRAMEWORK"])
    }

    on_exit(exit_fn)
    {:ok, contracts: contracts}
  end

  test "get_root_deployment_height/2 returns current block number", %{contracts: contracts} do
    {:ok, number} = RootChain.get_root_deployment_height(contracts.plasma_framework_tx_hash, contracts)
    assert is_integer(number)
  end

  test "get_next_child_block/1 returns next blknum to be mined by operator", %{contracts: contracts} do
    assert {:ok, 1000} = RootChain.get_next_child_block(contracts)
  end

  test "get_child_chain/2 returns the current block hash and timestamp", %{contracts: contracts} do
    {:ok, {child_chain_hash, child_chain_time}} = RootChain.get_child_chain(0, contracts)

    assert is_binary(child_chain_hash)
    assert byte_size(child_chain_hash) == 32
    assert is_integer(child_chain_time)
  end

  describe "get_standard_exit_structs/2" do
    test "returns a list of standard exits by the given exit ids", %{contracts: contracts} do
      {:ok, true} =
        Ethereumex.HttpClient.request(
          "personal_unlockAccount",
          [Encoding.to_hex(contracts.authority_address), "", 0],
          []
        )

      # Make 3 deposits so we can do 3 exits. 1 exit will not be queried, so we can check for false positives
      _ = add_queue(contracts.authority_address, contracts.plasma_framework)
      {utxo_pos_1, exit_1} = deposit_then_start_exit(contracts.authority_address, 1, @eth, contracts)
      {utxo_pos_2, _exit_2} = deposit_then_start_exit(contracts.authority_address, 2, @eth, contracts)
      {utxo_pos_3, exit_3} = deposit_then_start_exit(contracts.authority_address, 3, @eth, contracts)

      # Exit queue has not been added for some reason. We need it here so we add it.
      vault_id = 1
      {:ok, _} = RootChainHelper.add_exit_queue(vault_id, @eth, contracts)

      # Now get the exits by their ids and asserts the result
      exit_id_1 = exit_id_from_receipt(exit_1)
      exit_id_3 = exit_id_from_receipt(exit_3)

      {:ok, exits} = RootChain.get_standard_exit_structs([exit_id_1, exit_id_3], contracts)

      assert length(exits) == 2
      assert Enum.any?(exits, fn e -> elem(e, 1) == utxo_pos_1 end)
      refute Enum.any?(exits, fn e -> elem(e, 1) == utxo_pos_2 end)
      assert Enum.any?(exits, fn e -> elem(e, 1) == utxo_pos_3 end)
    end
  end

  defp deposit_then_start_exit(owner, amount, currency, contracts) do
    {:ok, deposit} = ExPlasma.Transaction.Deposit.new(owner: owner, currency: currency, amount: amount)
    rlp = ExPlasma.Transaction.encode(deposit)

    {:ok, deposit_tx} =
      rlp
      |> RootChainHelper.deposit(amount, owner, contracts)
      |> DevHelper.transact_sync!()

    deposit_txlog = hd(deposit_tx["logs"])
    deposit_blknum = Support.RootChainHelper.deposit_blknum_from_receipt(deposit_tx)
    deposit_txindex = OMG.Eth.Encoding.int_from_hex(deposit_txlog["transactionIndex"])

    utxo_pos = ExPlasma.Utxo.pos(%{blknum: deposit_blknum, txindex: deposit_txindex, oindex: 0})
    proof = ExPlasma.Encoding.merkle_proof([rlp], 0)

    {:ok, start_exit_tx} =
      utxo_pos
      |> RootChainHelper.start_exit(rlp, proof, owner, contracts)
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

  defp add_queue(authority_address, plasma_framework_address) do
    {:ok, true} =
      Ethereumex.HttpClient.request("personal_unlockAccount", [Encoding.to_hex(authority_address), "", 0], [])

    add_exit_queue =
      RootChainHelper.add_exit_queue(1, @eth, %{
        plasma_framework: plasma_framework_address
      })

    {:ok, %{"status" => "0x1"}} = Support.DevHelper.transact_sync!(add_exit_queue)
  end
end
