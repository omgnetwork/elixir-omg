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

defmodule OMG.Watcher.Web.Serializer.DBObjectTest do
  use ExUnit.Case, async: true

  alias OMG.Watcher.Web.Serializer.DBObject
  alias OMG.Watcher.TransactionDB

  @cleaned_tx %{
    blknum: nil,
    eth_height: nil,
    sent_at: nil,
    txbytes: nil,
    txhash: nil,
    txindex: nil
  }

  test "map of maps" do
    %{first: @cleaned_tx, second: @cleaned_tx}
    == DBObject.clean(%{second: %TransactionDB{}, first: %TransactionDB{}, })
  end

  test "list of maps" do
    assert [@cleaned_tx, @cleaned_tx] == DBObject.clean([%TransactionDB{}, %TransactionDB{}])
  end

  test "simple value list" do
    value = [nil, 1, "adam", :atom, [], %{}]

    assert value == DBObject.clean(value)
  end

  test "remove nested meta keys" do
    data = %{
      address: "0xd5b6e653beec1f8131d2ea4f574b2fd58770d9e0",
      utxos: [
        %{
          __meta__: %{context: nil, source: {nil, "txoutputs"}, state: :loaded},
          amount: 1,
          creating_deposit: "hash1",
          creating_transaction: nil,
          currency: "0000000000000000000000000000000000000000",
          deposit: %{
            __meta__: %{context: nil, source: {nil, "txoutputs"}, state: :loaded},
            deposit_blknum: 1,
            deposit_txindex: 0,
            event_type: :deposit,
            hash: "hash1"
          },
          id: 1
        }
      ]
    }
    |> DBObject.clean()

    assert false == Enum.any?(
      hd(data.utxos).deposit,
      &match?({:__meta__, _}, &1)
    )
  end

end
