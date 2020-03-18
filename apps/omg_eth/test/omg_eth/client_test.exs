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

defmodule OMG.Eth.ClientTest do
  use ExUnit.Case, async: true
  alias OMG.Eth.Client

  test "get_ethereum_height/0 returns the block number", %{test: test_name} do
    defmodule test_name do
      def eth_block_number() do
        {:ok, "0xfc"}
      end
    end

    {:ok, number} = Client.get_ethereum_height(test_name)
    assert is_integer(number)
  end

  test "node_ready/0 returns not ready", %{test: test_name} do
    defmodule test_name do
      def eth_syncing() do
        {:ok, true}
      end
    end

    assert Client.node_ready(test_name) == {:error, :geth_still_syncing}
  end

  test "node_ready/0 returns ready", %{test: test_name} do
    defmodule test_name do
      def eth_syncing() do
        {:ok, false}
      end
    end

    assert Client.node_ready(test_name) == :ok
  end

  test "node_ready/0 returns client unavailable ", %{test: test_name} do
    defmodule test_name do
      def eth_syncing() do
        {:error, :econnrefused}
      end
    end

    assert Client.node_ready(test_name) == {:error, :geth_not_listening}
  end

  # test "eth_call/1 returns correct response", %{test: test_name} do
  #   defmodule test_name do
  #     @to "0xc673e4ffcb8464faff908a6804fe0e635af0ea2f"
  #     @data "0x8c64ea4a0000000000000000000000000000000000000000000000000000000000000002"
  #     @return "0x000000000000000000000000135505d9f4ea773dd977de3b2b108f2dae67b63a"
  #     def eth_call(%{to: @to, data: @data}) do
  #       {:ok, @return}
  #     end
  #   end

  #   assert Client.call_contract(
  #            test_name,
  #            <<198, 115, 228, 255, 203, 132, 100, 250, 255, 144, 138, 104, 4, 254, 14, 99, 90, 240, 234, 47>>,
  #            "vaults(uint256)",
  #            [2],
  #            [:address]
  #          ) == {:ok, <<19, 85, 5, 217, 244, 234, 119, 61, 217, 119, 222, 59, 43, 16, 143, 45, 174, 103, 182, 58>>}
  # end
end
