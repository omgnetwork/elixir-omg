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

defmodule OMG.Watcher.API.AccountTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.DB.Fixtures

  alias OMG.TestHelper
  alias OMG.Watcher.API.Account

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @payment_output_type OMG.WireFormatTypes.output_type_for(:output_payment_v1)

  describe "get_exitable_utxos/1" do
    @tag fixtures: [:db_initialized]
    test "returns an empty list if the address does not have any utxo" do
      alice = TestHelper.generate_entity()
      assert Account.get_exitable_utxos(alice.addr) == []
    end

    @tag fixtures: [:db_initialized]
    test "returns utxos for the given address" do
      alice = TestHelper.generate_entity()
      bob = TestHelper.generate_entity()

      blknum = 1927
      txindex = 78
      oindex = 1

      _ =
        OMG.DB.multi_update([
          {:put, :utxo,
           {
             {blknum, txindex, oindex},
             %{
               output: %{amount: 333, currency: @eth, owner: alice.addr, output_type: @payment_output_type},
               creating_txhash: nil
             }
           }},
          {:put, :utxo,
           {
             {blknum, txindex, oindex + 1},
             %{
               output: %{amount: 999, currency: @eth, owner: bob.addr, output_type: @payment_output_type},
               creating_txhash: nil
             }
           }}
        ])

      [utxo] = Account.get_exitable_utxos(alice.addr)

      assert %{blknum: ^blknum, txindex: ^txindex, oindex: ^oindex} = utxo
    end
  end
end
