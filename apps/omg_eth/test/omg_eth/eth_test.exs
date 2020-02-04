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
  alias Support.SnapshotContracts
  use ExUnit.Case, async: false

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

    {:ok, true} = Ethereumex.HttpClient.request("personal_unlockAccount", [data["AUTHORITY_ADDRESS"], "", 0], [])

    on_exit(exit_fn)
    {:ok, contracts: contracts}
  end

  test "get_ethereum_height/0 returns the block number" do
    {:ok, number} = Eth.get_ethereum_height()
    assert is_integer(number)
  end

  test "get_block_timestamp_by_number/1 the block timestamp by block number" do
    {:ok, timestamp} = Eth.get_block_timestamp_by_number(2)
    assert is_integer(timestamp)
  end

  test "submit_block/1 submits a block to the contract", %{contracts: contracts} do
    response =
      Eth.submit_block(
        <<234::256>>,
        1,
        20_000_000_000,
        contracts.authority_address,
        contracts
      )

    assert {:ok, _} = DevHelper.transact_sync!(response)
  end
end
