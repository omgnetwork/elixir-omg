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

defmodule OMG.WatcherInfo.UtxoSelectionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures

  import OMG.WatcherInfo.Factory

  alias OMG.Utxo
  alias OMG.WatcherInfo.DB

  require Utxo

  @eth OMG.Eth.zero_address()

  @tag fixtures: [:phoenix_ecto_sandbox, :alice, :bob]
  test "create_advice returns correctly", %{alice: alice, bob: bob} do
    blknum = 11_000
    amount_1 = 1000
    amount_2 = 2000
    tx = OMG.TestHelper.create_recovered([], @eth, [{alice, amount_1}, {alice, amount_2}])
    utxos = DB.TxOutput.create_outputs(blknum, 0, tx.tx_hash, tx)

    params = %{
      owner: bob.addr,
      payments: [
        %{
          owner: alice.addr,
          currency: @eth,
          amount: 1000
        }
      ],
      fee: %{
        currency: @eth,
        amount: 1000
      },
      metadata: nil
    }

    outputs = Enum.map(utxos, fn (utxo) -> struct(DB.TxOutput, utxo) end)

    IO.inspect(outputs, label: "outputs")

    result = OMG.WatcherInfo.UtxoSelection.create_advice(%{"#{<<0::160>>}" => outputs}, params)
    # IO.inspect(result)
  end
end
