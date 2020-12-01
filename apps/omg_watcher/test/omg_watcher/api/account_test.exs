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

defmodule OMG.Watcher.API.AccountTest do
  use ExUnit.Case, async: false

  alias OMG.TestHelper
  alias OMG.Utxo
  alias OMG.Watcher.API.Account

  require Utxo

  @eth OMG.Eth.zero_address()
  @payment_output_type OMG.WireFormatTypes.output_type_for(:output_payment_v1)

  setup do
    db_path = Briefly.create!(directory: true)
    Application.put_env(:omg_db, :path, db_path, persistent: true)

    :ok = OMG.DB.init(db_path)

    {:ok, started_apps} = Application.ensure_all_started(:omg_db)

    on_exit(fn ->
      Application.put_env(:omg_db, :path, nil)

      started_apps
      |> Enum.reverse()
      |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end)

    :ok
  end

  describe "get_exitable_utxos/1" do
    test "returns an empty list if the address does not have any utxo" do
      alice = TestHelper.generate_entity()
      assert Account.get_exitable_utxos(alice.addr) == []
    end

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

    test "does not return exiting utxos" do
      alice = TestHelper.generate_entity()

      amount = 333
      blknum = 1927
      txindex = 78
      oindex = 1
      utxo_position = Utxo.position(blknum, txindex, oindex)

      _ =
        OMG.DB.multi_update([
          {:put, :utxo,
           {
             {blknum, txindex, oindex},
             %{
               output: %{amount: amount, currency: @eth, owner: alice.addr, output_type: @payment_output_type},
               creating_txhash: nil
             }
           }},
          {:put, :exit_info,
           {
             Utxo.Position.to_db_key(utxo_position),
             %{
               amount: amount,
               currency: @eth,
               owner: alice.addr,
               is_active: true,
               exit_id: 1,
               exiting_txbytes: <<0>>,
               eth_height: 1,
               root_chain_txhash: nil
             }
           }}
        ])

      assert [] == Account.get_exitable_utxos(alice.addr)
    end
  end
end
