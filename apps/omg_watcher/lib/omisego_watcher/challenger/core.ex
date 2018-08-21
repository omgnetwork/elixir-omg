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

defmodule OMGWatcher.Challenger.Core do
  @moduledoc """
  Functional core of challenger
  """

  alias OMG.API.Block
  alias OMG.API.State.Transaction
  alias OMG.API.Utxo
  require Utxo
  alias OMGWatcher.Challenger.Challenge
  alias OMGWatcher.TransactionDB

  @spec create_challenge(%TransactionDB{}, list(%TransactionDB{}), Utxo.Position.t()) :: Challenge.t()
  def create_challenge(challenging_tx, txs, utxo_exit) do
    txbytes = encode(challenging_tx)
    eutxoindex = get_eutxo_index(challenging_tx, utxo_exit)
    cutxopos = challenging_utxo_pos(challenging_tx)

    hashed_txs =
      txs
      |> Enum.sort_by(& &1.txindex)
      |> Enum.map(fn tx -> tx.txid end)

    proof = Block.create_tx_proof(hashed_txs, challenging_tx.txindex)

    Challenge.create(cutxopos, eutxoindex, txbytes, proof, challenging_tx.sig1 <> challenging_tx.sig2)
  end

  defp encode(%TransactionDB{
         blknum1: blknum1,
         txindex1: txindex1,
         oindex1: oindex1,
         blknum2: blknum2,
         txindex2: txindex2,
         oindex2: oindex2,
         cur12: cur12,
         newowner1: newowner1,
         amount1: amount1,
         newowner2: newowner2,
         amount2: amount2
       }) do
    tx = %Transaction{
      blknum1: blknum1,
      txindex1: txindex1,
      oindex1: oindex1,
      blknum2: blknum2,
      txindex2: txindex2,
      oindex2: oindex2,
      cur12: cur12,
      newowner1: newowner1,
      amount1: amount1,
      newowner2: newowner2,
      amount2: amount2
    }

    Transaction.encode(tx)
  end

  defp get_eutxo_index(
         %TransactionDB{blknum1: blknum, txindex1: txindex, oindex1: oindex},
         Utxo.position(blknum, txindex, oindex)
       ),
       do: 0

  defp get_eutxo_index(
         %TransactionDB{blknum2: blknum, txindex2: txindex, oindex2: oindex},
         Utxo.position(blknum, txindex, oindex)
       ),
       do: 1

  defp challenging_utxo_pos(challenging_tx) do
    challenging_tx
    |> get_challenging_utxo()
    |> Utxo.Position.encode()
  end

  defp get_challenging_utxo(%TransactionDB{txblknum: blknum, txindex: txindex, amount1: 0}),
    do: Utxo.position(blknum, txindex, 1)

  defp get_challenging_utxo(%TransactionDB{txblknum: blknum, txindex: txindex}),
    do: Utxo.position(blknum, txindex, 0)
end
