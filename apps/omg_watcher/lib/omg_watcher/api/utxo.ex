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

defmodule OMG.Watcher.API.Utxo do
  @moduledoc """
  Module provides API for utxos
  """
  alias OMG.Block
  alias OMG.State.Transaction
  alias OMG.Utxo
  alias OMG.Watcher.ExitProcessor

  use OMG.Utils.Metrics
  require Utxo

  @type exit_t() :: %{
          utxo_pos: pos_integer(),
          txbytes: binary(),
          proof: binary(),
          sigs: binary()
        }

  @doc """
  Returns a proof that utxo was spent
  """
  @decorate measure_event()
  @spec create_challenge(Utxo.Position.t()) ::
          {:ok, ExitProcessor.StandardExitChallenge.t()} | {:error, :utxo_not_spent} | {:error, :exit_not_found}
  def create_challenge(utxo) do
    ExitProcessor.create_challenge(utxo)
  end

  @decorate measure_event()
  @spec compose_utxo_exit(Utxo.Position.t()) :: {:ok, exit_t()} | {:error, :utxo_not_found}
  def compose_utxo_exit(Utxo.position(blknum, txindex, _) = decoded_utxo_pos) do
    if Utxo.Position.is_deposit?(decoded_utxo_pos) do
      compose_deposit_exit(decoded_utxo_pos)
    else
      with {:ok, blk_hashes} <- OMG.DB.block_hashes([blknum]),
           {:ok, [%{transactions: transactions}]} <- OMG.DB.blocks(blk_hashes),
           true <- length(transactions) > txindex do
        {:ok, compose_output_exit(transactions, decoded_utxo_pos)}
      else
        _error ->
          {:error, :utxo_not_found}
      end
    end
  end

  @decorate measure_event()
  defp compose_deposit_exit(Utxo.position(blknum, _, _) = decoded_utxo_pos) do
    with {:ok, utxos} <- OMG.DB.utxos(),
         {_, %{amount: amount, currency: currency, owner: owner}} <-
           utxos |> Enum.find(fn {{blk, _, _}, _} -> blk == blknum end) do
      tx = Transaction.new([], [{owner, currency, amount}])

      txs = [%Transaction.Signed{raw_tx: tx, sigs: []} |> Transaction.Signed.encode()]

      {:ok,
       %{
         utxo_pos: decoded_utxo_pos |> Utxo.Position.encode(),
         txbytes: tx |> Transaction.raw_txbytes(),
         proof: Block.inclusion_proof(txs, 0)
       }}
    else
      _ -> {:error, :no_deposit_for_given_blknum}
    end
  end

  @decorate measure_event()
  defp compose_output_exit(sorted_tx_bytes, Utxo.position(_blknum, txindex, _) = decoded_utxo_pos) do
    signed_tx = Enum.at(sorted_tx_bytes, txindex)

    {:ok, %Transaction.Signed{sigs: sigs} = tx} = Transaction.Signed.decode(signed_tx)

    proof = sorted_tx_bytes |> Block.inclusion_proof(txindex)

    utxo_pos = decoded_utxo_pos |> Utxo.Position.encode()
    sigs = Enum.join(sigs)

    %{
      utxo_pos: utxo_pos,
      txbytes: Transaction.raw_txbytes(tx),
      proof: proof,
      sigs: sigs
    }
  end
end
