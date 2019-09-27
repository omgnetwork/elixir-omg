# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.Watcher.UtxoExit.Core do
  @moduledoc """
  Module provides API for compose exit
  """

  alias OMG.Block
  alias OMG.State.Transaction
  alias OMG.Utxo

  require Utxo

  def compose_output_exit(:not_found, _), do: {:error, :utxo_not_found}

  def compose_output_exit(db_block, Utxo.position(blknum, txindex, _) = utxo_pos) do
    %Block{transactions: sorted_txs_bytes, number: ^blknum} = block = Block.from_db_value(db_block)

    if signed_tx_bytes = Enum.at(sorted_txs_bytes, txindex) do
      signed_tx = Transaction.Signed.decode!(signed_tx_bytes)

      {:ok,
       %{
         utxo_pos: Utxo.Position.encode(utxo_pos),
         txbytes: Transaction.raw_txbytes(signed_tx),
         proof: Block.inclusion_proof(block, txindex)
       }}
    else
      {:error, :utxo_not_found}
    end
  end

  @spec get_deposit_utxo({:ok, list({OMG.DB.utxo_pos_db_t(), Transaction.Payment.output()})}, Utxo.Position.t()) ::
          nil | Transaction.Payment.output()
  def get_deposit_utxo({:ok, utxos}, Utxo.position(blknum, _, _)) do
    case Enum.find(utxos, fn {{blk, _, _}, _} -> blk == blknum end) do
      {_, utxo} -> utxo
      _ -> nil
    end
  end

  @spec compose_deposit_exit(Transaction.Payment.output() | any(), Utxo.Position.t()) ::
          {:error, :no_deposit_for_given_blknum}
          | {:ok,
             %{
               utxo_pos: non_neg_integer,
               txbytes: binary,
               proof: binary
             }}
  def compose_deposit_exit(%{amount: amount, currency: currency, owner: owner}, utxo_pos) do
    tx = Transaction.Payment.new([], [{owner, currency, amount}])
    txs = [Transaction.Signed.encode(%Transaction.Signed{raw_tx: tx, sigs: []})]

    {:ok,
     %{
       utxo_pos: Utxo.Position.encode(utxo_pos),
       txbytes: Transaction.raw_txbytes(tx),
       proof: Block.inclusion_proof(txs, 0)
     }}
  end

  def compose_deposit_exit(_, _), do: {:error, :no_deposit_for_given_blknum}
end
