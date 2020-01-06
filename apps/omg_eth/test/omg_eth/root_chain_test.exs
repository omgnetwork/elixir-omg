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

defmodule OMG.Eth.RootChainTest do
  alias OMG.Eth
  alias OMG.Eth.Encoding
  alias OMG.Eth.RootChain
  alias Support.DevHelper
  alias Support.RootChainHelper

  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @moduletag :common

  setup do
    vcr_path = Path.join(__DIR__, "../fixtures/vcr_cassettes")
    ExVCR.Config.cassette_library_dir(vcr_path)

    contracts = %{
      plasma_framework_tx_hash: Encoding.from_hex("0xcd96b40b8324a4e10b421d6dd9796d200c64f7af6799f85262fa8951aed2f10c"),
      plasma_framework: Encoding.from_hex("0xc673e4ffcb8464faff908a6804fe0e635af0ea2f"),
      eth_vault: Encoding.from_hex("0x0433420dee34412b5bf1e29fbf988ad037cc5db7"),
      erc20_vault: Encoding.from_hex("0x04badc20426bc146453c5b879417b25029fa6c73"),
      payment_exit_game: Encoding.from_hex("0x92ce4d7773c57d96210c46a07b89acf725057f21"),
      authority_address: Encoding.from_hex("0xc0f780dfc35075979b0def588d999225b7ecc56f")
    }

    {:ok, contracts: contracts}
  end

  test "get_root_deployment_height/2 returns current block number", %{contracts: contracts} do
    use_cassette "ganache/get_root_deployment_height", match_requests_on: [:request_body] do
      {:ok, number} = RootChain.get_root_deployment_height(contracts.plasma_framework_tx_hash, contracts)
      assert is_integer(number)
    end
  end

  test "get_next_child_block/1 returns next blknum to be mined by operator", %{contracts: contracts} do
    use_cassette "ganache/get_next_child_block", match_requests_on: [:request_body] do
      assert {:ok, 1000} = RootChain.get_next_child_block(contracts)
    end
  end

  describe "has_token/2" do
    # TODO achiurizo
    #
    # Figure out why I can't use the same cassettes even though request_body is unique
    @tag :skip
    test "returns true  if token exists", %{contracts: contracts} do
      use_cassette "ganache/has_token_true", match_requests_on: [:request_body] do
        assert {:ok, true} = RootChainHelper.has_token(@eth, contracts)
      end
    end

    # TODO achiurizo
    #
    # Skipping these specs for now as this function needs to be updated
    # to use the new ALD function (not hasToken?)
    @tag :skip
    test "returns false if no token exists", %{contracts: contracts} do
      use_cassette "ganache/has_token_false", match_requests_on: [:request_body] do
        assert {:ok, false} = RootChainHelper.has_token(<<1::160>>, contracts)
      end
    end
  end

  test "get_child_chain/2 returns the current block hash and timestamp", %{contracts: contracts} do
    use_cassette "ganache/get_child_chain", match_requests_on: [:request_body] do
      {:ok, {child_chain_hash, child_chain_time}} = RootChain.get_child_chain(0, contracts)

      assert is_binary(child_chain_hash)
      assert byte_size(child_chain_hash) == 32
      assert is_integer(child_chain_time)
    end
  end

  test "get_deposits/3 returns deposit events", %{contracts: contracts} do
    use_cassette "ganache/get_deposits", match_requests_on: [:request_body] do
      # not using OMG.ChildChain.Transaction to not depend on that in omg_eth tests
      # payment tx_type, no inputs, one output, metadata
      tx =
        [owner: contracts.authority_address, currency: @eth, amount: 1]
        |> ExPlasma.Transactions.Deposit.new()
        |> ExPlasma.Transaction.encode()

      {:ok, tx_hash} =
        RootChainHelper.deposit(tx, 1, contracts.authority_address, contracts)
        |> DevHelper.transact_sync!()

      {:ok, height} = Eth.get_ethereum_height()

      authority_addr = contracts.authority_address
      root_chain_txhash = Encoding.from_hex(tx_hash["transactionHash"])

      deposits = RootChain.get_deposits(1, height, contracts)

      assert {:ok,
              [
                %{
                  amount: 1,
                  blknum: 1,
                  owner: ^authority_addr,
                  currency: @eth,
                  eth_height: height,
                  log_index: 0,
                  root_chain_txhash: ^root_chain_txhash
                }
              ]} = deposits
    end
  end

  describe "get_standard_exits_structs/2" do
    test "returns a list of standard exits by the given exit ids", %{contracts: contracts} do
      use_cassette "ganache/get_standard_exits_structs", match_requests_on: [:request_body] do
        # Make 3 deposits so we can do 3 exits. 1 exit will not be queried, so we can check for false positives
        {utxo_pos_1, exit_1} = deposit_then_start_exit(contracts.authority_address, 1, @eth, contracts)
        {utxo_pos_2, _exit_2} = deposit_then_start_exit(contracts.authority_address, 2, @eth, contracts)
        {utxo_pos_3, exit_3} = deposit_then_start_exit(contracts.authority_address, 3, @eth, contracts)

        # Exit queue has not been added for some reason. We need it here so we add it.
        vault_id = 1
        {:ok, _} = RootChainHelper.add_exit_queue(vault_id, @eth, contracts)

        # Now get the exits by their ids and asserts the result
        exit_id_1 = exit_id_from_receipt(exit_1)
        exit_id_3 = exit_id_from_receipt(exit_3)

        {:ok, exits} = RootChain.get_standard_exits_structs([exit_id_1, exit_id_3], contracts)

        assert length(exits) == 2
        assert Enum.any?(exits, fn e -> elem(e, 1) == utxo_pos_1 end)
        refute Enum.any?(exits, fn e -> elem(e, 1) == utxo_pos_2 end)
        assert Enum.any?(exits, fn e -> elem(e, 1) == utxo_pos_3 end)
      end
    end
  end

  defp deposit_then_start_exit(owner, amount, currency, contracts) do
    rlp =
      [owner: owner, currency: currency, amount: amount]
      |> ExPlasma.Transactions.Deposit.new()
      |> ExPlasma.Transaction.encode()

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
      |> to_hex()

    [%{exit_id: exit_id}] =
      logs
      |> Enum.filter(&(topic in &1["topics"]))
      |> Enum.map(fn log ->
        Eth.parse_events_with_indexed_fields(
          log,
          {[:exit_id], [{:uint, 160}]},
          {[:owner], [:address]}
        )
      end)

    exit_id
  end
end
