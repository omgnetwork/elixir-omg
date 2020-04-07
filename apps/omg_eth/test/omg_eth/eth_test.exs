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

  """
  use ExUnit.Case, async: false

  alias OMG.Eth
  alias OMG.Eth.Configuration
  alias Support.DevHelper

  @moduletag :common

  setup_all do
    {:ok, exit_fn} = Support.DevNode.start()
    authority_address = Configuration.authority_address()
    {:ok, true} = Ethereumex.HttpClient.request("personal_unlockAccount", [authority_address, "", 0], [])

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
