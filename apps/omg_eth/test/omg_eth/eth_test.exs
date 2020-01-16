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

defmodule OMG.EthTest do
  @moduledoc """
  Thin smoke test of the Ethereum port/adapter.
  The purpose of this test to only prod the marshalling and calling functionalities of the `Eth` wrapper.
  This shouldn't test the contract and should rely as little as possible on the contract logic.
  `OMG.Eth` is intended to be as thin and deprived of own logic as possible, to not require extensive testing.

  Note the excluded moduletag, this test requires an explicit `--include wrappers`
  """

  alias OMG.Eth
  alias OMG.Eth.Encoding
  alias Support.DevHelper

  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

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

  test "get_ethereum_height/0 returns the block number" do
    use_cassette "ganache/get_ethereum_height", match_requests_on: [:request_body] do
      {:ok, number} = Eth.get_ethereum_height()
      assert is_integer(number)
    end
  end

  test "get_block_timestamp_by_number/1 the block timestamp by block number" do
    use_cassette "ganache/get_block_timestamp_by_number", match_requests_on: [:request_body] do
      {:ok, timestamp} = Eth.get_block_timestamp_by_number(2)
      assert is_integer(timestamp)
    end
  end

  test "submit_block/1 submits a block to the contract", %{contract: contract} do
    use_cassette "ganache/submit_block", match_requests_on: [:request_body] do
      response =
        Eth.submit_block(
          <<234::256>>,
          1,
          20_000_000_000,
          contract.authority_address,
          contract
        )

      assert {:ok, _} = DevHelper.transact_sync!(response)
    end
  end
end
