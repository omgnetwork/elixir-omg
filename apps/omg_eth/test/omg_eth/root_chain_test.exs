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

    contract = %{
      # NOTE: achiurizo
      # this has changed with ALD(see plasma-contrats deploy of plasma_framework)
      # it's now :plasma_framework_tx_hash instead of :txhash_contract
      txhash_contract: Encoding.from_hex("0x3d517d431daea71a99310f12468ffdf2bf547ad1d148f42acfc4ee34dd4e84d7"),
      plasma_framework: Encoding.from_hex("0xd17e1233a03affb9092d5109179b43d6a8828607"),
      eth_vault: Encoding.from_hex("0x1967d06b1faba91eaadb1be33b277447ea24fa0e"),
      erc20_vault: Encoding.from_hex("0xaef6182310e3d34b6ea138b60d36a245386f3201"),
      payment_exit_game: Encoding.from_hex("0x902719f192aa5240632f704aa7a94bab61b86550"),
      authority_address: Encoding.from_hex("0x22d491bde2303f2f43325b2108d26f1eaba1e32b")
    }

    {:ok, contract: contract}
  end

  test "get_root_deployment_height/2 returns current block number", %{contract: contract} do
    use_cassette "ganache/get_root_deployment_height", match_requests_on: [:request_body] do
      {:ok, number} = RootChain.get_root_deployment_height(contract.txhash_contract, contract)
      assert is_integer(number)
    end
  end

  test "get_next_child_block/1 returns next blknum to be mined by operator", %{contract: contract} do
    use_cassette "ganache/get_next_child_block", match_requests_on: [:request_body] do
      assert {:ok, 2000} = RootChain.get_next_child_block(contract)
    end
  end

  describe "has_token/2" do
    # TODO achiurizo
    #
    # Figure out why I can't use the same cassettes even though request_body is unique
    @tag :skip
    test "returns true  if token exists", %{contract: contract} do
      use_cassette "ganache/has_token_true", match_requests_on: [:request_body] do
        assert {:ok, true} = RootChainHelper.has_token(@eth, contract)
      end
    end

    # TODO achiurizo
    #
    # Skipping these specs for now as this function needs to be updated
    # to use the new ALD function (not hasToken?)
    @tag :skip
    test "returns false if no token exists", %{contract: contract} do
      use_cassette "ganache/has_token_false", match_requests_on: [:request_body] do
        assert {:ok, false} = RootChainHelper.has_token(<<1::160>>, contract)
      end
    end
  end

  test "get_child_chain/2 returns the current block hash and timestamp", %{contract: contract} do
    use_cassette "ganache/get_child_chain", match_requests_on: [:request_body] do
      {:ok, {child_chain_hash, child_chain_time}} = RootChain.get_child_chain(0, contract)

      assert is_binary(child_chain_hash)
      assert byte_size(child_chain_hash) == 32
      assert is_integer(child_chain_time)
    end
  end

  # TODO achiurizo
  #
  # ganache complaining about invalid output encoding
  test "get_deposits/3 returns deposit events", %{contract: contract} do
    use_cassette "ganache/get_deposits", match_requests_on: [:request_body] do
      # not using OMG.ChildChain.Transaction to not depend on that in omg_eth tests
      # payment tx_type, no inputs, one output, metadata
      tx =
        [1, [], [[1, contract.authority_address, @eth, 1]], <<0::256>>]
        |> ExRLP.encode()

      {:ok, tx_hash} =
        RootChainHelper.deposit(tx, 1, contract.authority_address, contract)
        |> DevHelper.transact_sync!()

      {:ok, height} = Eth.get_ethereum_height()

      authority_addr = contract.authority_address
      root_chain_txhash = Encoding.from_hex(tx_hash["transactionHash"])

      deposits = RootChain.get_deposits(1, height, contract)

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
end
