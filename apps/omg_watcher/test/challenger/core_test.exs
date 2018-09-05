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

defmodule OMG.Watcher.Challenger.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.API.State.Transaction
  alias OMG.API.State.Transaction.Signed
  alias OMG.API.Utxo
  alias OMG.Watcher.Challenger.Challenge
  alias OMG.Watcher.Challenger.Core
  alias OMG.Watcher.TransactionDB
  alias OMG.Watcher.TxOutputDB

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
        newowner1: <<0::160>>,
        amount1: amount1,
        newowner2: <<1::160>>,
        amount2: amount2
      },
      sig1: <<0::(65*8)>>,
      sig2: <<0::(65*8)>>
    }

    txhash = Signed.signed_hash(signed)

    %TransactionDB{
      blknum: 2,
      txindex: txindex,
      txhash: txhash,
      inputs: [
        %TxOutputDB{creating_tx_oindex: 0, spending_tx_oindex: 0},
      ],
      outputs: [
        %TxOutputDB{creating_tx_oindex: 0},
        %TxOutputDB{creating_tx_oindex: 1},
      ],
      txbytes: Signed.encode(signed)
    }
  end

  @tag fixtures: [:transactions]
  test "creates a challenge for an exit", %{transactions: transactions} do
    utxo_exit = Utxo.position(1, 0, 0)
    challenging_tx = hd(transactions)

    expected_cutxopos = Utxo.position(2, 1, 0) |> Utxo.Position.encode()

    %Challenge{cutxopos: ^expected_cutxopos, eutxoindex: 0} =
      Core.create_challenge(challenging_tx, transactions)

      #FIXME: do smth w/ test
    ## Maybe test makes no longer any sense in this shape
    # [_, challenging_tx | _] = transactions
    # IO.inspect challenging_tx

    # expected_cutxopos = Utxo.position(2, 2, 1) |> Utxo.Position.encode()

    # %Challenge{cutxopos: ^expected_cutxopos, eutxoindex: 0} =
    #   Core.create_challenge(challenging_tx, transactions)

    # utxo_exit = Utxo.position(1, 0, 1)

    # %Challenge{cutxopos: ^expected_cutxopos, eutxoindex: 1} =
    #   Core.create_challenge(challenging_tx, transactions)
  end
end
