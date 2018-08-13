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

defmodule OmiseGOWatcher.Challenger.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.State.Transaction.Signed
  alias OmiseGO.API.Utxo
  alias OmiseGOWatcher.Challenger.Challenge
  alias OmiseGOWatcher.Challenger.Core
  alias OmiseGOWatcher.TransactionDB

  require Utxo

  deffixture transactions do
    [
      create_transaction(1, 5, 0),
      create_transaction(2, 0, 4)
    ]
  end

  defp create_transaction(txindex, amount1, amount2) do
    signed = %Signed{
      raw_tx: %Transaction{
        blknum1: 1,
        txindex1: 0,
        oindex1: 0,
        blknum2: 1,
        txindex2: 0,
        oindex2: 1,
        cur12: <<0::160>>,
        newowner1: "alice",
        amount1: amount1,
        newowner2: "bob",
        amount2: amount2
      },
      sig1: "sig1",
      sig2: "sig2"
    }

    txid = Signed.signed_hash(signed)

    %TransactionDB{
      blknum1: 1,
      txindex1: 0,
      oindex1: 0,
      blknum2: 1,
      txindex2: 0,
      oindex2: 1,
      cur12: <<0::160>>,
      newowner1: "",
      amount1: amount1,
      newowner2: "",
      amount2: amount2,
      txblknum: 2,
      txindex: txindex,
      txid: txid,
      sig1: "sig1",
      sig2: "sig2"
    }
  end

  @tag fixtures: [:transactions]
  test "creates a challenge for an exit", %{transactions: transactions} do
    utxo_exit = Utxo.position(1, 0, 0)
    challenging_tx = hd(transactions)

    expected_cutxopos = Utxo.position(2, 1, 0) |> Utxo.Position.encode()

    %Challenge{cutxopos: ^expected_cutxopos, eutxoindex: 0} =
      Core.create_challenge(challenging_tx, transactions, utxo_exit)

    [_, challenging_tx | _] = transactions

    expected_cutxopos = Utxo.position(2, 2, 1) |> Utxo.Position.encode()

    %Challenge{cutxopos: ^expected_cutxopos, eutxoindex: 0} =
      Core.create_challenge(challenging_tx, transactions, utxo_exit)

    utxo_exit = Utxo.position(1, 0, 1)

    %Challenge{cutxopos: ^expected_cutxopos, eutxoindex: 1} =
      Core.create_challenge(challenging_tx, transactions, utxo_exit)
  end
end
