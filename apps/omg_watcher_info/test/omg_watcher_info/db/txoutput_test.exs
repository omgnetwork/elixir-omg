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

  alias OMG.Utxo
  alias OMG.WatcherInfo.DB

  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()

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
end
