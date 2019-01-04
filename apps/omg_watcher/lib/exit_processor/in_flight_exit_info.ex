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

defmodule OMG.Watcher.ExitProcessor.InFlightExitInfo do
  @moduledoc """
  Represents the bulk of information about a tracked in-flight exit.

  Internal stuff of `OMG.Watcher.ExitProcessor`
  """

  alias OMG.API.State.Transaction

  @output_index_range 0..7

  @block_offset 1_000_000_000
  @tx_offset 10_000

  defstruct [
    :tx,
    :tx_pos,
    :timestamp,
    :oldest_competitor,
    # piggybacking
    exit_map:
      @output_index_range
      |> Enum.map(&{&1, %{is_piggybacked: false, is_finalized: false}})
      |> Map.new(),
    is_canonical: true,
    is_active: true
  ]

  @type tx_position() :: {pos_integer(), non_neg_integer()}

  @type t :: %__MODULE__{
          tx: Transaction.Signed.t(),
          tx_pos: tx_position(),
          timestamp: non_neg_integer(),
          oldest_competitor: {non_neg_integer(), non_neg_integer()},
          exit_map: %{
            non_neg_integer() => %{
              is_piggybacked: boolean(),
              is_finalized: boolean()
            }
          },
          is_canonical: boolean(),
          is_active: boolean()
        }

  def build_in_flight_transaction_info(tx_bytes, tx_signatures, timestamp, is_active) do
    with {:ok, raw_tx} <- Transaction.decode(tx_bytes) do
      signed_tx_map = %{
        raw_tx: raw_tx,
        sigs: tx_signatures
      }

      {
        Transaction.hash(raw_tx),
        %__MODULE__{
          tx: struct(Transaction.Signed, signed_tx_map),
          timestamp: timestamp,
          is_active: is_active
        }
      }
    end
  end

  def make_db_update({_ife_hash, %__MODULE__{} = _ife} = update) do
    {:put, :in_flight_exit_info, update}
  end

  @spec piggyback(t(), non_neg_integer()) :: {:ok, t()} | {:error, :non_existent_exit | :cannot_piggyback}
  def piggyback(ife, index)

  def piggyback(%__MODULE__{exit_map: exit_map} = ife, index) when index in @output_index_range do
    with exit <- Map.get(exit_map, index),
         {:ok, updated_exit} <- piggyback_exit(exit) do
      {:ok, %{ife | exit_map: Map.merge(exit_map, %{index => updated_exit})}}
    end
  end

  def piggyback(%__MODULE__{}, _), do: {:error, :non_existent_exit}

  defp piggyback_exit(%{is_piggybacked: false, is_finalized: false}),
    do: {:ok, %{is_piggybacked: true, is_finalized: false}}

  defp piggyback_exit(_), do: {:error, :cannot_piggyback}

  @spec challenge(t(), non_neg_integer()) :: {:ok, t()} | {:error, :cannot_challenge}
  def challenge(ife, competitor_position)

  def challenge(%__MODULE__{oldest_competitor: nil} = ife, competitor_position),
    do: %{ife | is_canonical: false, oldest_competitor: decode_tx_position(competitor_position)}

  def challenge(%__MODULE__{oldest_competitor: current_oldest} = ife, competitor_position) do
    with decoded_competitor_pos <- decode_tx_position(competitor_position),
         true <- is_older?(decoded_competitor_pos, current_oldest) do
      %{ife | is_canonical: false, oldest_competitor: decoded_competitor_pos}
    else
      _ -> {:error, :cannot_challenge}
    end
  end

  @spec challenge_piggyback(t(), integer()) :: {:ok, t()} | {:error, :non_existent_exit | :cannot_challenge}
  def challenge_piggyback(ife, index)

  def challenge_piggyback(%__MODULE__{exit_map: exit_map} = ife, index) when index in @output_index_range do
    with %{is_piggybacked: true, is_finalized: false} <- Map.get(exit_map, index) do
      {:ok, %{ife | exit_map: Map.merge(exit_map, %{index => %{is_piggybacked: false, is_finalized: false}})}}
    else
      _ -> {:error, :cannot_challenge}
    end
  end

  def challenge_piggyback(%__MODULE__{}, _), do: {:error, :non_existent_exit}

  @spec respond_to_challenge(t(), pos_integer()) :: {:ok, t()} | :error
  def respond_to_challenge(ife, tx_position)

  def respond_to_challenge(%__MODULE__{oldest_competitor: nil, tx_pos: nil} = ife, tx_position) do
    decoded = decode_tx_position(tx_position)
    {:ok, %{ife | oldest_competitor: decoded, is_canonical: true, tx_pos: decoded}}
  end

  def respond_to_challenge(%__MODULE__{oldest_competitor: current_oldest, tx_pos: nil} = ife, tx_position) do
    decoded = decode_tx_position(tx_position)

    if is_older?(decoded, current_oldest) do
      {:ok, %{ife | oldest_competitor: decoded, is_canonical: true, tx_pos: decoded}}
    else
      :error
    end
  end

  def respond_to_challenge(%__MODULE__{}, _), do: :error

  @spec get_exiting_utxo_positions(t()) :: list({:utxo_position, non_neg_integer(), non_neg_integer(), non_neg_integer})
  def get_exiting_utxo_positions(ife)

  #  def get_exiting_utxo_positions(%__MODULE__{is_canonical: false} = ife) do
  #    ife.inputs
  #    |> Enum.with_index()
  #    |> Enum.filter(&is_active?(ife, :input, elem(&1, 1)))
  #    |> Enum.map(
  #      &(&1
  #        |> elem(0)
  #        |> elem(0))
  #    )
  #  end
  #
  #  def get_exiting_utxo_positions(ife = %__MODULE__{is_canonical: true, tx_pos: tx_pos}) when tx_pos != nil do
  #    active_outputs_offsets =
  #      ife.outputs
  #      |> Enum.with_index()
  #      |> Enum.filter(&is_active?(ife, :input, elem(&1, 1)))
  #      |> Enum.map(
  #        &(&1
  #          |> elem(1))
  #      )
  #
  #    {:utxo_position, blknum, tx_index, _} = tx_pos
  #    for pos <- active_outputs_offsets, do: {:utxo_position, blknum, tx_index, pos}
  #  end

  def get_exiting_utxo_positions(_ife) do
    []
  end

  def is_piggybacked?(%__MODULE__{exit_map: map}, index) do
    with {:ok, exit} <- Map.fetch(map, index) do
      Map.get(exit, :is_piggybacked)
    else
      :error -> false
    end
  end

  def is_finalized?(%__MODULE__{exit_map: map}, index) do
    with {:ok, exit} <- Map.fetch(map, index) do
      Map.get(exit, :is_finalized)
    else
      :error -> false
    end
  end

  def is_active?(%__MODULE__{} = ife, index) do
    is_piggybacked?(ife, index) and !is_finalized?(ife, index)
  end

  def is_canonical?(%__MODULE__{is_canonical: value}), do: value

  #  defp offset(:input), do: 0
  #  defp offset(:output), do: 4

  defp is_older?({tx1_blknum, tx1_index}, {tx2_blknum, tx2_index}),
    do: tx1_blknum < tx2_blknum or (tx1_blknum == tx2_blknum and tx1_index < tx2_index)

  defp decode_tx_position(tx_position) do
    tx_index = rem(tx_position, @block_offset) |> div(@tx_offset)
    blknum = div(tx_position, @block_offset)
    {blknum, tx_index}
  end
end
