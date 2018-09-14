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

defmodule OMG.Watcher.Challenger.Core do
  @moduledoc """
  Functional core of challenger
  """

  alias OMG.API.Block
  alias OMG.API.State.Transaction
  alias OMG.API.State.Transaction.Signed
  alias OMG.API.Utxo
  require Utxo
  alias OMG.Watcher.Challenger.Challenge
  alias OMG.Watcher.DB.TransactionDB

  @spec create_challenge(%TransactionDB{}, list(%TransactionDB{})) :: Challenge.t()
  def create_challenge(challenging_tx, txs) do
    # See: [contract's challengeExit](https://github.com/omisego/plasma-contracts/blob/22936d561a036d49aa6a215531e70c5779df058f/contracts/RootChain.sol#L244)
    # eUtxoIndex - The output position of the exiting utxo.
    eutxoindex = get_eutxo_index(challenging_tx)
    # cUtxoPos - The position of the challenging utxo.
    cutxopos = challenging_utxo_pos(challenging_tx)

    txs_hashes =
      txs
      |> Enum.sort_by(& &1.txindex)
      |> Enum.map(& &1.txhash)

    proof = Block.create_tx_proof(txs_hashes, challenging_tx.txindex)
    {:ok, signed_tx} = Signed.decode(challenging_tx.txbytes)
    raw_txbytes = encode(challenging_tx)

    Challenge.create(cutxopos, eutxoindex, raw_txbytes, proof, signed_tx.sig1 <> signed_tx.sig2)
  end

  defp encode(%TransactionDB{txbytes: txbytes}) do
    {:ok, %Signed{raw_tx: raw_tx}} = Signed.decode(txbytes)
    Transaction.encode(raw_tx)
  end

  defp challenging_utxo_pos(%TransactionDB{
         outputs: [output | _],
         blknum: blknum,
         txindex: txindex
       }) do
    Utxo.position(blknum, txindex, output.creating_tx_oindex)
    |> Utxo.Position.encode()
  end

  # here: challenging_tx is prepared to contain just utxo_exit input only,
  # see: TransactionDB.get_transaction_challenging_utxo/1
  defp get_eutxo_index(%TransactionDB{inputs: [input]}),
    do: input.spending_tx_oindex
end
