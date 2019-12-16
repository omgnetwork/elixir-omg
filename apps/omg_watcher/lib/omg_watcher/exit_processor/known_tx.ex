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

defmodule OMG.Watcher.ExitProcessor.KnownTx do
  @moduledoc """
  Wrapps information about a particular signed transaction known from somewhere, optionally with its UTXO position

  Private
  """
  defstruct [:signed_tx, :utxo_pos]

  alias OMG.Block
  alias OMG.State.Transaction
  alias OMG.Utxo
  alias OMG.Watcher.ExitProcessor.Core
  alias OMG.Watcher.ExitProcessor.TxAppendix

  require Utxo

  @type t() :: %__MODULE__{
          signed_tx: Transaction.Signed.t(),
          utxo_pos: Utxo.Position.t() | nil
        }

  @type known_txs_by_input_t() :: %{Utxo.Position.t() => list(__MODULE__.t())}

  def new(%Transaction.Signed{} = signed_tx, {:utxo_position, _, _, _} = utxo_pos),
    do: %__MODULE__{signed_tx: signed_tx, utxo_pos: utxo_pos}

  def new(%Transaction.Signed{} = signed_tx),
    do: %__MODULE__{signed_tx: signed_tx}

  def get_positions_by_txhash(blocks) do
    blocks
    |> get_all_from()
    # cannot simply `Enum.into` here, because for every position the tx might have been included, we need the oldest
    |> Enum.group_by(&Transaction.raw_txhash(&1.signed_tx), & &1.utxo_pos)
    |> Enum.into(%{}, fn {txhash, positions} -> {txhash, hd(positions)} end)
  end

  def get_blocks_by_blknum(blocks),
    do: blocks |> Enum.into(%{}, fn %Block{number: blknum} = block -> {blknum, block} end)

  def find_tx_in_blocks(txhash, positions_by_tx_hash, blocks_by_blknum) do
    txhash
    |> (&Map.get(positions_by_tx_hash, &1)).()
    |> case do
      nil -> nil
      {:utxo_position, blknum, _, _} = position -> {blocks_by_blknum[blknum], position}
    end
  end

  @doc """
  Groups the spending transactions by the input spent, preserves the sorting for every input.

  Expects an `Enumberable` of `KnownTx`s
  Duplicates are possible.
  """
  @spec group_txs_by_input(Enumerable.t()) :: known_txs_by_input_t
  def group_txs_by_input(all_known_txs) do
    all_known_txs
    |> Stream.map(&{&1, Transaction.get_inputs(&1.signed_tx)})
    |> Stream.flat_map(fn {known_tx, inputs} -> for input <- inputs, do: {input, known_tx} end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  # returns the known transactions in the proper order - first ones from blocks sorted from oldest then ones
  # from outside of blocks (TxAppendix)
  def get_all_from_blocks_appendix(blocks, %Core{} = processor) do
    [get_all_from(blocks), get_all_from(processor)]
    |> Stream.concat()
    |> group_txs_by_input()
  end

  defp get_all_from(%Core{} = processor) do
    TxAppendix.get_all(processor)
    |> Stream.map(&new/1)
  end

  defp get_all_from(%Block{transactions: txs, number: blknum}) do
    txs
    |> Stream.map(&Transaction.Signed.decode!/1)
    |> Stream.with_index()
    |> Stream.map(fn {signed, txindex} -> new(signed, {:utxo_position, blknum, txindex, 0}) end)
  end

  defp get_all_from(blocks) when is_list(blocks), do: blocks |> sort_blocks() |> Stream.flat_map(&get_all_from/1)

  # we're sorting the blocks by their blknum here, because we wan't oldest (best) competitors first always
  defp sort_blocks(blocks), do: blocks |> Enum.sort_by(fn %Block{number: number} -> number end)

  def is_older?(%__MODULE__{utxo_pos: utxo_pos1}, %__MODULE__{utxo_pos: utxo_pos2}) do
    cond do
      is_nil(utxo_pos1) -> false
      is_nil(utxo_pos2) -> true
      true -> 
        {:utxo_position, blknum1, txindex1, oindex1} = utxo_pos1
        {:utxo_position, blknum2, txindex2, oindex2} = utxo_pos2
        encoded_pos1 = ExPlasma.Utxo.pos(%{blknum: blknum1, txindex: txindex1, oindex: oindex1})
        encoded_pos2 = ExPlasma.Utxo.pos(%{blknum: blknum2, txindex: txindex2, oindex: oindex2})
        encoded_pos1 < encoded_pos2
    end
  end
end
