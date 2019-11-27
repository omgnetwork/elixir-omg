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

defmodule OMG.WatcherRPC.Web.View.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Watcher.Fixtures

  alias OMG.Utils.Paginator
  alias OMG.Watcher.DB
  alias OMG.WatcherRPC.Web.View
  # alias OMG.Utxo
  # alias Support.WatcherHelper
  # require Utxo

  # @eth OMG.Eth.RootChain.eth_pseudo_address()

  describe "render/2" do
    @tag fixtures: [:initial_blocks]
    test "renders transaction.json", %{initial_blocks: initial_blocks} do
      transaction = initial_blocks.transactions |> IO.inspect() |> Enum.at(0)

      expected = %{
        data: %{
          block: %{
            blknum: 1000,
            eth_height: 100_000,
            hash: "0x00000000000000000000000000000000000000000000000000000000000004d2",
            timestamp: 1574764345
          },
          inputs: [],
          metadata: "0x00",
          outputs: [],
          txbytes: "0x0000000000000000000000000000000000000000000000000000000000000000",
          txhash: nil,
          txindex: 1
        },
        service_name: "child_chain",
        success: true,
        version: "0.3.0+"
      }

      assert View.Transaction.render("transaction.json", %{response: transaction}) == expected
    end

    test "renders transactions.json", %{initial_blocks: initial_blocks} do
      paginator = %Paginator{
        data: [],
        data_paging: %{
          limit: 10,
          page: 1
        }
      }

      expected = %{
        data: [
          %{
            block: %{
              blknum: 1000,
              eth_height: 100_000,
              hash: "0x00000000000000000000000000000000000000000000000000000000000004d2",
              timestamp: 1574764345
            },
            inputs: [],
            metadata: "0x00",
            outputs: [],
            results: [],
            txbytes: "0x0000000000000000000000000000000000000000000000000000000000000000",
            txhash: nil,
            txindex: 1
          }
        ],
        data_paging: %{
          limit: 10,
          page: 1
        },
        service_name: "child_chain",
        success: true,
        version: "0.3.0+"
      }

      assert View.Transaction.render("transactions.json", %{response: paginator}) == expected
    end
  end
end
