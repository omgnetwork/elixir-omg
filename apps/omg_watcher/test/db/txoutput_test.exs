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

defmodule OMG.Watcher.DB.TxOutputTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures

  alias OMG.Utxo
  alias OMG.Watcher.DB

  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @tag fixtures: [:initial_blocks]
  test "compose_utxo_exit should return proper proof format" do
    {:ok,
     %{
       utxo_pos: _utxo_pos,
       txbytes: _txbytes,
       proof: proof,
       sigs: _sigs
     }} = DB.TxOutput.compose_utxo_exit(Utxo.position(3000, 0, 1))

    assert <<_proof::bytes-size(512)>> = proof
  end

  @tag fixtures: [:initial_blocks]
  test "compose_utxo_exit should return error when there is no txs in specfic block" do
    {:error, :no_deposit_for_given_blknum} = DB.TxOutput.compose_utxo_exit(Utxo.position(1001, 1, 0))
  end

  @tag fixtures: [:initial_blocks]
  test "compose_utxo_exit should return error when there is no tx in specfic block" do
    {:error, :utxo_not_found} = DB.TxOutput.compose_utxo_exit(Utxo.position(2000, 1, 0))
  end

  @tag fixtures: [:phoenix_ecto_sandbox, :alice]
  test "transaction output schema handles big numbers properly", %{alice: alice} do
    power_of_2 = fn n -> :lists.duplicate(n, 2) |> Enum.reduce(&(&1 * &2)) end
    assert 16 == power_of_2.(4)

    big_amount = power_of_2.(260)

    DB.Transaction.update_with(%{
      transactions: [
        OMG.TestHelper.create_recovered([], @eth, [{alice, big_amount}])
      ],
      blknum: 11_000,
      blkhash: <<?#::256>>,
      timestamp: :os.system_time(:second),
      eth_height: 10
    })

    utxo = DB.TxOutput.get_by_position(Utxo.position(11_000, 0, 0))
    assert not is_nil(utxo)
    assert utxo.amount == big_amount
  end
end
