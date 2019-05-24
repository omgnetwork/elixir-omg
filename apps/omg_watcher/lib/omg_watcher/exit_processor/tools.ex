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

defmodule OMG.Watcher.ExitProcessor.Tools do
  @moduledoc """
  Private tools that various components of the `ExitProcessor` share
  """

  alias OMG.Crypto
  alias OMG.State.Transaction
  alias OMG.TypedDataHash
  alias OMG.Utxo

  require Utxo

  defmodule KnownTx do
    @moduledoc """
    Wrapps information about a particular signed transaction known from somewhere, optionally with its UTXO position

    Private
    """
    defstruct [:signed_tx, :utxo_pos]

    @type t() :: %__MODULE__{
            signed_tx: Transaction.Signed.t(),
            utxo_pos: Utxo.Position.t() | nil
          }
  end

  defmodule DoubleSpend do
    @moduledoc """
    Wraps information about a single double spend occuring between a verified transaction and a known transaction
    """

    defstruct [:index, :utxo_pos, :known_spent_index, :known_tx]

    @type t() :: %__MODULE__{
            index: non_neg_integer(),
            utxo_pos: Utxo.Position.t(),
            known_spent_index: non_neg_integer,
            known_tx: KnownTx.t()
          }
  end

  # Intersects utxos, looking for duplicates. Gives full list of double-spends with indexes for
  # a pair of transactions.
  @spec double_spends_from_known_tx(list({Utxo.Position.t(), non_neg_integer()}), KnownTx.t()) ::
          list(DoubleSpend.t())
  def double_spends_from_known_tx(inputs, %KnownTx{signed_tx: signed} = known_tx) when is_list(inputs) do
    known_spent_inputs = signed |> Transaction.get_inputs() |> Enum.with_index()

    # TODO: possibly ineffective if Transaction.max_inputs >> 4
    for {left, left_index} <- inputs,
        {right, right_index} <- known_spent_inputs,
        left == right,
        do: %DoubleSpend{index: left_index, utxo_pos: left, known_spent_index: right_index, known_tx: known_tx}
  end

  # based on an enumberable of `Utxo.Position` and a mapping that tells whether one exists it will pick
  # only those that **were checked** and were missing
  # (i.e. those not checked are assumed to be present)
  def only_utxos_checked_and_missing(utxo_positions, utxo_exists?) do
    # the default value below is true, so that the assumption is that utxo not checked is **present**
    # TODO: rather inefficient, but no as inefficient as the nested `filter` calls in searching for competitors
    #       consider optimizing using `MapSet`

    Enum.filter(utxo_positions, fn utxo_pos -> !Map.get(utxo_exists?, utxo_pos, true) end)
  end

  @doc """
  Finds the exact signature which signed the particular transaction for the given owner address
  """
  @spec find_sig(Transaction.Signed.t(), Crypto.address_t()) :: {:ok, Crypto.sig_t()} | nil
  def find_sig(%Transaction.Signed{sigs: sigs, raw_tx: raw_tx}, owner) do
    tx_hash = TypedDataHash.hash_struct(raw_tx)

    Enum.find(sigs, fn sig ->
      {:ok, owner} == Crypto.recover_address(tx_hash, sig)
    end)
    |> case do
      nil -> nil
      other -> {:ok, other}
    end
  end

  @doc """
  Throwing version of `find_sig/2`

  At some point having a tx that wasn't actually signed is an error, hence pattern match
  if `find_sig/2` returns nil it means somethings very wrong - the owner taken (effectively) from the contract
  doesn't appear to have signed the potential competitor, which means that some prior signature checking was skipped
  """
  def find_sig!(tx, owner) do
    {:ok, sig} = find_sig(tx, owner)
    sig
  end
end
