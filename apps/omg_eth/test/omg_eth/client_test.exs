# Copyright 2019-2020 OMG Network Pte Ltd
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
end
