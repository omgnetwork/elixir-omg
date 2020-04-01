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
  alias OMG.Eth.ReleaseTasks.SetContract
  alias Support.DevHelper
  alias Support.SnapshotContracts

  use ExUnit.Case, async: false

  @moduletag :common

  setup_all do
    {:ok, exit_fn} = Support.DevNode.start()

    data = SnapshotContracts.parse_contracts()

    :ok = System.put_env("ETHEREUM_NETWORK", "LOCALCHAIN")
    :ok = System.put_env("TXHASH_CONTRACT", data["AUTHORITY_ADDRESS"])
    :ok = System.put_env("AUTHORITY_ADDRESS", data["AUTHORITY_ADDRESS"])
    :ok = System.put_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK", data["CONTRACT_ADDRESS_PLASMA_FRAMEWORK"])
    config = SetContract.load([], [])
    Application.put_all_env(config)

    {:ok, true} = Ethereumex.HttpClient.request("personal_unlockAccount", [data["AUTHORITY_ADDRESS"], "", 0], [])

    on_exit(exit_fn)
    :ok
  end

  test "get_block_timestamp_by_number/1 the block timestamp by block number" do
    {:ok, timestamp} = Eth.get_block_timestamp_by_number(2)
    assert is_integer(timestamp)
  end

  test "submit_block/1 submits a block to the contract" do
    response = Eth.submit_block(<<234::256>>, 1, 20_000_000_000)

    assert {:ok, _} = DevHelper.transact_sync!(response)
  end
end
