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

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  @moduletag :wrappers
  @moduletag :common

  setup do
    {:ok, _} = Application.ensure_all_started(:ethereumex)
    ExVCR.Config.cassette_library_dir("test/fixtures/vcr_cassettes")
    :ok
  end

  test "get_ethereum_height/0 returns the block number" do
    use_cassette "get_ethereum_height", match_requests_on: [:request_body] do
      {:ok, number} = Eth.get_ethereum_height()
      assert is_integer(number)
    end
  end

  test "get_block_timestamp_by_number/1 the block timestamp by block number" do
    use_cassette "get_ethereum_height", match_requests_on: [:request_body] do
      {:ok, timestamp} = Eth.get_block_timestamp_by_number(2)
      assert is_integer(timestamp)
    end
  end
end
