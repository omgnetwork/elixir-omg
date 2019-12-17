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

  def compose_block_standard_exit(:not_found, _), do: {:error, :utxo_not_found}

  def compose_block_standard_exit(db_block, %OMG.InputPointer{blknum: blknum, txindex: txindex, oindex: oindex} = utxo_pos) do
    %Block{transactions: sorted_txs_bytes, number: ^blknum} = block = Block.from_db_value(db_block)

    with {:ok, signed_tx_bytes} <- get_tx_by_index(sorted_txs_bytes, txindex),
         signed_tx = Transaction.Signed.decode!(signed_tx_bytes),
         :ok <- get_output_by_index(signed_tx, utxo_pos) do
      {:ok,
       %{
         utxo_pos: ExPlasma.Utxo.pos(%{blknum: blknum, txindex: txindex, oindex: oindex}),
         txbytes: Transaction.raw_txbytes(signed_tx),
         proof: Block.inclusion_proof(block, txindex)
       }}
    end
  end

  @spec compose_deposit_standard_exit({:ok, {tuple, map}} | :not_found) ::
          {:error, :no_deposit_for_given_blknum}
          | {:ok, %{utxo_pos: non_neg_integer, txbytes: binary, proof: binary}}
  def compose_deposit_standard_exit({:ok, {db_utxo_pos, db_utxo_value}}) do
    # TODO: Refactor this, or use pattern matching to make it more clear
    # what type data is being passed into the OMG.InputPointer protocol.
    %OMG.InputPointer{blknum: blknum, txindex: txindex, oindex: oindex} = OMG.InputPointer.from_db_key(db_utxo_pos)

    %OMG.Utxo{output: %OMG.Output.FungibleMoreVPToken{amount: amount, currency: currency, owner: owner}} =
      OMG.Utxo.from_db_value(db_utxo_value)

    tx = Transaction.Payment.new([], [{owner, currency, amount}])
    txs = [Transaction.Signed.encode(%Transaction.Signed{raw_tx: tx, sigs: []})]

    {:ok,
     %{
       utxo_pos: ExPlasma.Utxo.pos(%{blknum: blknum, txindex: txindex, oindex: oindex}),
       txbytes: Transaction.raw_txbytes(tx),
       proof: Block.inclusion_proof(txs, 0)
     }}
  end

  def compose_deposit_standard_exit(:not_found), do: {:error, :no_deposit_for_given_blknum}

  defp get_tx_by_index(sorted_txs, txindex) do
    sorted_txs
    |> Enum.at(txindex)
    |> case do
      nil -> {:error, :utxo_not_found}
      found -> {:ok, found}
    end
  end

  defp get_output_by_index(tx, %OMG.InputPointer{blknum: _, txindex: _, oindex: oindex}) do
    tx
    |> Transaction.get_outputs()
    |> Enum.at(oindex)
    |> case do
      nil -> {:error, :utxo_not_found}
      _found -> :ok
    end
  end
end
