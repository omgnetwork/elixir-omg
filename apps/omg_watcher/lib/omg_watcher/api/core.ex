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

defmodule OMG.Watcher.API.Core do
  @moduledoc """
  Module provides API for compose exit
  """

  alias OMG.Block
  alias OMG.State.Transaction
  alias OMG.Utxo
  use OMG.Utils.Metrics
  require Utxo

  @decorate measure_event()
  def compose_output_exit([%{txindex: _} | _] = txs, Utxo.position(_, txindex, _) = decoded_utxo_pos) do
    if txs |> Enum.any?(&match?(%{txindex: ^txindex}, &1)) do
      sorted_tx_bytes =
        txs
        |> Enum.sort_by(& &1.txindex)
        |> Enum.map(& &1.txbytes)

      compose_output_exit(sorted_tx_bytes, decoded_utxo_pos)
    else
      {:error, :utxo_not_found}
    end
  end

  @decorate measure_event()
  def compose_output_exit(sorted_tx_bytes, Utxo.position(_blknum, txindex, _) = decoded_utxo_pos) do
    if signed_tx = Enum.at(sorted_tx_bytes, txindex) do
      {:ok, %Transaction.Signed{sigs: sigs} = tx} = Transaction.Signed.decode(signed_tx)
      proof = sorted_tx_bytes |> Block.inclusion_proof(txindex)

      utxo_pos = decoded_utxo_pos |> Utxo.Position.encode()
      sigs = Enum.join(sigs)

      {:ok,
       %{
         utxo_pos: utxo_pos,
         txbytes: Transaction.raw_txbytes(tx),
         proof: proof,
         sigs: sigs
       }}
    else
      {:error, :utxo_not_found}
    end
  end

  @decorate measure_event()
  def get_deposit_utxo(utxos, Utxo.position(blknum, _, _)) do
    with {:ok, utxos} <- utxos,
         {_, utxo} <- utxos |> Enum.find(fn {{blk, _, _}, _} -> blk == blknum end) do
      utxo
    else
      _ -> nil
    end
  end

  @decorate measure_event()
  def compose_deposit_exit(%{amount: amount, currency: currency, owner: owner}, decoded_utxo_pos) do
    tx = Transaction.new([], [{owner, currency, amount}])
    txs = [%Transaction.Signed{raw_tx: tx, sigs: []} |> Transaction.Signed.encode()]

    {:ok,
     %{
       utxo_pos: decoded_utxo_pos |> Utxo.Position.encode(),
       txbytes: tx |> Transaction.raw_txbytes(),
       proof: Block.inclusion_proof(txs, 0)
     }}
  end

  @decorate measure_event()
  def compose_deposit_exit(_, _), do: {:error, :no_deposit_for_given_blknum}
end
