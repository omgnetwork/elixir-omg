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

defmodule OMG.WatcherInfo.UtxoSelectionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures

  import OMG.WatcherInfo.Factory

  alias OMG.Utxo
  alias OMG.WatcherInfo.DB

  require Utxo

  @eth OMG.Eth.zero_address()

  @spec generate_utxos_map(pos_integer, Transaction.Payment.currency(), list({map, pos_integer})) :: %{
          Transaction.Payment.currency() => list(%DB.TxOutput{})
        }
  defp generate_utxos_map(blknum, currency, funds) do
    tx = OMG.TestHelper.create_recovered([], currency, funds)

    utxos =
      blknum
      |> DB.TxOutput.create_outputs(0, tx.tx_hash, tx)
      |> Enum.map(fn utxo -> struct(DB.TxOutput, utxo) end)

    %{currency => utxos}
  end

  @tag fixtures: [:phoenix_ecto_sandbox, :alice, :bob]
  test "create_advice returns {:ok, %{result: :complete}}", %{alice: alice, bob: bob} do
    amount_1 = 1000
    amount_2 = 2000
    utxos = generate_utxos_map(10_000, @eth, [{alice, amount_1}, {alice, amount_2}])

    order = %{
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

    assert {:ok, %{result: :complete}} = OMG.WatcherInfo.UtxoSelection.create_advice(utxos, order)
  end
end
