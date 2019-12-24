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

defmodule OMG.WatcherRPC.Web.View.UtxoTest do
  use ExUnit.Case, async: false

  alias OMG.Utils.Paginator
  alias OMG.Utxo
  alias OMG.WatcherInfo.DB
  alias OMG.WatcherRPC.Web.View

  require Utxo

  describe "render/2 with deposits.json" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "renders the deposits" do
#      deposit_1 = DB.Transaction.get_by_position(1000, 0) |> DB.Repo.preload([:inputs, :outputs])
#      deposit_2 = DB.Transaction.get_by_position(1000, 1) |> DB.Repo.preload([:inputs, :outputs])

#      paginator = %Paginator{
#        data: [deposit_1, deposit_2],
#        data_paging: %{
#         limit: 10,
#         page: 1
#        }
#      }

#      rendered = View.Utxo.render("deposits.json", %{response: paginator})
#      [rendered_1, rendered_2] = rendered.data

#      assert utxos_match_all?(rendered_1.inputs, tx_1.inputs)
      assert true == false
    end
  end
end
