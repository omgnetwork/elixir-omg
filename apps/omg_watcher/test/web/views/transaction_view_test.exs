# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.Watcher.Web.TransactionViewTest do
  @moduledoc false
  use OMG.Watcher.ViewCase

  alias OMG.Watcher.Web.Serializer
  alias OMG.Watcher.Web.View

  test "renders transaction.json with correct response format" do
    transaction = %{
      txid: <<>>,
      blknum1: 0,
      txindex1: 0,
      oindex1: 0,
      blknum2: 0,
      txindex2: 0,
      oindex2: 0,
      cur12: <<>>,
      newowner1: <<>>,
      amount1: 0,
      newowner2: <<>>,
      amount2: 0,
      txblknum: 0,
      txindex: 0,
      sig1: <<>>,
      sig2: <<>>,
      spender1: <<>>,
      spender2: <<>>
    }

    expected = %{
      result: :success,
      data:
        Serializer.Response.encode16(transaction, [
          "txid",
          "cur12",
          "newowner1",
          "newowner2",
          "sig1",
          "sig2",
          "spender1",
          "spender2"
        ])
    }

    assert View.Transaction.render("transaction.json", %{transaction: transaction}) == expected
  end
end
