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
      plasma_framework_tx_hash: Encoding.from_hex("0xcd96b40b8324a4e10b421d6dd9796d200c64f7af6799f85262fa8951aed2f10c"),
      plasma_framework: Encoding.from_hex("0xc673e4ffcb8464faff908a6804fe0e635af0ea2f"),
      eth_vault: Encoding.from_hex("0x0433420dee34412b5bf1e29fbf988ad037cc5db7"),
      erc20_vault: Encoding.from_hex("0x04badc20426bc146453c5b879417b25029fa6c73"),
      payment_exit_game: Encoding.from_hex("0x92ce4d7773c57d96210c46a07b89acf725057f21"),
      authority_address: Encoding.from_hex("0xc0f780dfc35075979b0def588d999225b7ecc56f")
    }

    {:ok, contract: contract}
  end

  test "get_root_deployment_height/2 returns current block number", %{contract: contract} do
    use_cassette "ganache/get_root_deployment_height", match_requests_on: [:request_body] do
      {:ok, number} = RootChain.get_root_deployment_height(contract.plasma_framework_tx_hash, contract)
      assert is_integer(number)
    end
  end

  test "get_next_child_block/1 returns next blknum to be mined by operator", %{contract: contract} do
    use_cassette "ganache/get_next_child_block", match_requests_on: [:request_body] do
      assert {:ok, 1000} = RootChain.get_next_child_block(contract)
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

  test "get_deposits/3 returns deposit events", %{contract: contract} do
    use_cassette "ganache/get_deposits", match_requests_on: [:request_body] do
      # not using OMG.ChildChain.Transaction to not depend on that in omg_eth tests
      # payment tx_type, no inputs, one output, metadata
      tx =
        [owner: contract.authority_address, currency: @eth, amount: 1]
        |> ExPlasma.Transactions.Deposit.new()
        |> ExPlasma.Transaction.encode()

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
