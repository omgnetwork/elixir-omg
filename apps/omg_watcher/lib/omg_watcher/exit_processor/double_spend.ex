# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.Watcher.ExitProcessor.DoubleSpend do
  @moduledoc """
  Wraps information about a single double spend occuring between a verified transaction and a known transaction
  """

  defstruct [:index, :utxo_pos, :known_spent_index, :known_tx]

  alias OMG.Watcher.State.Transaction
  alias OMG.Watcher.Utxo
  alias OMG.Watcher.ExitProcessor.KnownTx
  alias OMG.Watcher.ExitProcessor.Tools

  @type t() :: %__MODULE__{
          index: non_neg_integer(),
          utxo_pos: Utxo.Position.t(),
          known_spent_index: non_neg_integer,
          known_tx: KnownTx.t()
        }

  @doc """
  Finds the single, oldest competitor from a set of known transactions grouped by input. `nil` if there's none

  `known_txs_by_input` are assumed to hold _the oldest_ transaction spending given input for every input
  """
  @spec find_competitor(KnownTx.known_txs_by_input_t(), Transaction.any_flavor_t()) :: nil | t()
  def find_competitor(known_txs_by_input, tx) do
    inputs = Transaction.get_inputs(tx)

    known_txs_by_input
    |> all_distinct_spends_of_inputs(inputs, tx)
    # need to sort, to get the oldest transaction (double-) spending for _all the_ inputs of `tx`
    |> Enum.sort(&KnownTx.is_older?/2)
    |> Enum.at(0)
    |> case do
      nil -> nil
      known_tx -> inputs |> Enum.with_index() |> Tools.double_spends_from_known_tx(known_tx) |> hd()
    end
  end

  @doc """
  Gets all the double spends found in an `known_txs_by_input`, following an indexed breakdown of particular
  utxo_positions of `tx`.

  This is useful if the interesting utxo positions aren't just inputs of `tx` (e.g. piggybacking, tx's outputs, etc.)
  """
  @spec all_double_spends_by_index(
          list({Utxo.Position.t(), non_neg_integer}),
          map(),
          Transaction.any_flavor_t()
        ) :: %{non_neg_integer => t()}
  def all_double_spends_by_index(indexed_utxo_positions, known_txs_by_input, tx) do
    {inputs, _indices} = Enum.unzip(indexed_utxo_positions)

    # Will find all spenders of provided indexed inputs.
    known_txs_by_input
    |> all_distinct_spends_of_inputs(inputs, tx)
    |> Stream.flat_map(&Tools.double_spends_from_known_tx(indexed_utxo_positions, &1))
    |> Enum.group_by(& &1.index)
  end

  # filters all the transactions, spending any of the inputs, distinct from `tx` - to find all the double-spending txs
  defp all_distinct_spends_of_inputs(known_txs_by_input, inputs, tx) do
    known_txs_by_input
    |> Map.take(inputs)
    |> Stream.flat_map(fn {_input, spending_txs} -> spending_txs end)
    |> Stream.filter(&Tools.txs_different(tx, &1.signed_tx))
  end
end
