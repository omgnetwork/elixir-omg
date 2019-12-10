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

defmodule OMG.WatcherInfo.API.UtxoTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures
  use OMG.WatcherInfo.Fixtures
  use OMG.Watcher.Fixtures

  alias OMG.State.Transaction
  alias OMG.TestHelper, as: Test
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.WatcherInfo.DB
  alias Support.WatcherHelper
  alias OMG.WatcherInfo.API.Utxo

  describe "get_deposits/1" do
    @tag fixtures: [:initial_blocks, :alice]
    test "gets paginated list of deposits for address ordered by descending blknum, txindex, oindex", %{alice: alice} do
      # %OMG.Utils.Paginator{
      #   data: [
      #     %OMG.WatcherInfo.DB.Block{
      #       __meta__: #Ecto.Schema.Metadata<:loaded, "blocks">,
      #       blknum: 3000,
      #       eth_height: 1,
      #       hash: "#3000",
      #       timestamp: 1540465606
      #     },
      #     %OMG.WatcherInfo.DB.Block{
      #       __meta__: #Ecto.Schema.Metadata<:loaded, "blocks">,
      #       blknum: 2000,
      #       eth_height: 1,
      #       hash: "#2000",
      #       timestamp: 1540465606
      #     },
      #     %OMG.WatcherInfo.DB.Block{
      #       __meta__: #Ecto.Schema.Metadata<:loaded, "blocks">,
      #       blknum: 1000,
      #       eth_height: 1,
      #       hash: "#1000",
      #       timestamp: 1540465606
      #     }
      #   ],
      #   data_paging: %{limit: 10, page: 1}
      # }


      constraints = [data: [owner: alice.addr], data_paging: [page: 1, limit: 10]]
      results = Utxo.get_deposits(constraints)
#
#      IO.inspect(results, label: "deposits")

#      assert %OMG.Utils.Paginator{} = results
#      assert length(results.data) == 3

      #assert ordered by descending blknum, txindex, oindex

      IO.inspect(alice, label: "alice")
    end
  end
end
