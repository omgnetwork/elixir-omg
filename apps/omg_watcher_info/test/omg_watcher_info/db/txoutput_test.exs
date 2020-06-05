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

defmodule OMG.WatcherInfo.DB.TxOutputTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures

  import OMG.WatcherInfo.Factory

  alias OMG.Utxo
  alias OMG.WatcherInfo.DB

  require Utxo

  @eth OMG.Eth.zero_address()

  @tag fixtures: [:phoenix_ecto_sandbox, :alice]
  test "transaction output schema handles big numbers properly", %{alice: alice} do
    power_of_2 = fn n -> :lists.duplicate(n, 2) |> Enum.reduce(&(&1 * &2)) end
    assert 16 == power_of_2.(4)

    big_amount = power_of_2.(256) - 1

    DB.Block.insert_with_transactions(%{
      transactions: [OMG.TestHelper.create_recovered([], @eth, [{alice, big_amount}])],
      blknum: 11_000,
      blkhash: <<?#::256>>,
      timestamp: :os.system_time(:second),
      eth_height: 10
    })

    utxo = DB.TxOutput.get_by_position(Utxo.position(11_000, 0, 0))
    assert not is_nil(utxo)
    assert utxo.amount == big_amount
  end

  describe "create_outputs/4" do
    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "create outputs according to params", %{alice: alice} do
      blknum = 11_000
      amount_1 = 1000
      amount_2 = 2000
      tx = OMG.TestHelper.create_recovered([], @eth, [{alice, amount_1}, {alice, amount_2}])

      assert [
               %{
                 amount: amount_1,
                 blknum: blknum,
                 creating_txhash: tx.tx_hash,
                 currency: @eth,
                 oindex: 0,
                 otype: 1,
                 owner: alice.addr,
                 txindex: 0
               },
               %{
                 amount: amount_2,
                 blknum: blknum,
                 creating_txhash: tx.tx_hash,
                 currency: @eth,
                 oindex: 1,
                 otype: 1,
                 owner: alice.addr,
                 txindex: 0
               }
             ] == DB.TxOutput.create_outputs(blknum, 0, tx.tx_hash, tx)
    end
  end

  describe "OMG.WatcherInfo.DB.TxOutput.spend_utxos/3" do
    # a special test for spend_utxos/3 is here because under the hood it calls update_all/3. using
    # update_all/3 with a queryable means that certain autogenerated columns, such as inserted_at and
    # updated_at, will not be updated as they would be if you used a plain update. More info
    # is here: https://hexdocs.pm/ecto/Ecto.Repo.html#c:update_all/3
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "spend_utxos updates the updated_at timestamp correctly" do
      deposit = :txoutput |> build() |> with_deposit()

      :transaction |> insert() |> with_inputs([deposit])

      txinput = DB.TxOutput.get_by_position(Utxo.position(deposit.blknum, deposit.txindex, deposit.oindex))

      spend_utxo_params = spend_uxto_params_from_txoutput(txinput)

      _ = DB.Repo.transaction(DB.TxOutput.spend_utxos(Ecto.Multi.new(), [spend_utxo_params]))
      spent_txoutput = DB.TxOutput.get_by_position(Utxo.position(txinput.blknum, txinput.txindex, txinput.oindex))

      assert :eq == DateTime.compare(txinput.inserted_at, spent_txoutput.inserted_at)
      assert :lt == DateTime.compare(txinput.updated_at, spent_txoutput.updated_at)
    end
  end
end
