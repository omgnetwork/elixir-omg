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

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @moduletag :wrappers
  @moduletag :common

  setup do
    ExVCR.Config.cassette_library_dir("test/fixtures/vcr_cassettes")
    :ok
  end

  @tag fixtures: [:eth_node]
  test "get_ethereum_height and get_block_timestamp_by_number return integers" do
    use_cassette "get_ethereum_height" do
      assert {:ok, number} = Eth.get_ethereum_height()
      assert {:ok, timestamp} = Eth.get_block_timestamp_by_number(number)
      assert is_integer(number)
      assert is_integer(timestamp)
    end
  end
end
