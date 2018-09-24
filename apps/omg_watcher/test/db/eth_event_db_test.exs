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

defmodule OMG.Watcher.DB.EthEventDBTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.API.Fixtures

  alias OMG.API.Crypto
  alias OMG.API.Utxo
  alias OMG.Watcher.DB.EthEventDB
  alias OMG.Watcher.DB.TxOutputDB

  require Utxo

  @eth Crypto.zero_address()

  describe "EthEvent database" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "insert deposits: creates deposit event and utxo" do
      owner = <<1::160>>
      EthEventDB.insert_deposits([%{blknum: 1, owner: owner, currency: @eth, amount: 1, hash: "hash1"}])

      [event] = EthEventDB.get_all()
      assert %EthEventDB{deposit_blknum: 1, deposit_txindex: 0, event_type: :deposit, hash: "hash1"} = event

      [utxo] = TxOutputDB.get_all()
      assert %TxOutputDB{owner: ^owner, currency: @eth, amount: 1, creating_deposit: "hash1"} = utxo
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "insert deposits: creates deposits and retrieves them by hash", %{alice: alice} do
      [{:ok, _evnt1}, {:ok, _evnt2}, {:ok, _evnt3}] =
        EthEventDB.insert_deposits([
          %{blknum: 1, owner: alice.addr, currency: @eth, amount: 1, hash: "hash1"},
          %{blknum: 1000, owner: alice.addr, currency: @eth, amount: 2, hash: "hash2"},
          %{blknum: 2013, owner: alice.addr, currency: @eth, amount: 3, hash: "hash3"}
        ])

      assert %EthEventDB{deposit_blknum: 1, deposit_txindex: 0, event_type: :deposit} = EthEventDB.get("hash1")

      assert %EthEventDB{deposit_blknum: 1000, deposit_txindex: 0, event_type: :deposit} = EthEventDB.get("hash2")

      assert %EthEventDB{deposit_blknum: 2013, deposit_txindex: 0, event_type: :deposit} = EthEventDB.get("hash3")

      assert ["hash1", "hash2", "hash3"] == TxOutputDB.get_utxos(alice.addr) |> Enum.map(& &1.creating_deposit)
    end
  end
end
