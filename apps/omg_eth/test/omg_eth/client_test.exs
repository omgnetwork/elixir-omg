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
  alias OMG.Eth.Encoding

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

  test "get_transaction_by_hash/0 returns transaction data", %{test: test_name} do
    tx_hash =
      <<136, 223, 1, 100, 41, 104, 156, 7, 159, 59, 47, 106, 211, 159, 160, 82, 83, 44, 86, 121, 91, 115, 61, 167, 138,
        145, 235, 230, 167, 19, 148, 75>>

    tx_hash_hex = "0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b" = Encoding.to_hex(tx_hash)

    defmodule test_name do
      def eth_get_transaction_by_hash(
            "0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b" = tx_hash_hex
          ) do
        {:ok,
         %{
           "blockHash" => "0x1d59ff54b1eb26b013ce3cb5fc9dab3705b415a67127a003c3e61eb445bb8df2",
           "blockNumber" => "0x5daf3b",
           "from" => "0xa7d9ddbe1f17865597fbd27ec712455208b6b76d",
           "gas" => "0xc350",
           "gasPrice" => "0x4a817c800",
           "hash" => tx_hash_hex,
           "input" => "0x68656c6c6f21",
           "nonce" => "0x15",
           "to" => "0xf02c1c8e6114b1dbe8937a39260b5b0a374432bb",
           "transactionIndex" => "0x41",
           "value" => "0xf3dbb76162000",
           "v" => "0x25",
           "r" => "0x1b5e176d927f8e9ab405058b2d2457392da3e20f328b16ddabcebc33eaac5fea",
           "s" => "0x4ba69724e8f69de52f0125ad8b3c5c2cef33019bac3249e2c0a2192766d1721c"
         }}
      end
    end

    assert Client.get_transaction_by_hash(tx_hash, test_name) ==
             {:ok,
              %{
                "blockHash" => "0x1d59ff54b1eb26b013ce3cb5fc9dab3705b415a67127a003c3e61eb445bb8df2",
                "blockNumber" => "0x5daf3b",
                "from" => "0xa7d9ddbe1f17865597fbd27ec712455208b6b76d",
                "gas" => "0xc350",
                "gasPrice" => "0x4a817c800",
                "hash" => tx_hash_hex,
                "input" => "0x68656c6c6f21",
                "nonce" => "0x15",
                "to" => "0xf02c1c8e6114b1dbe8937a39260b5b0a374432bb",
                "transactionIndex" => "0x41",
                "value" => "0xf3dbb76162000",
                "v" => "0x25",
                "r" => "0x1b5e176d927f8e9ab405058b2d2457392da3e20f328b16ddabcebc33eaac5fea",
                "s" => "0x4ba69724e8f69de52f0125ad8b3c5c2cef33019bac3249e2c0a2192766d1721c"
              }}
  end
end
