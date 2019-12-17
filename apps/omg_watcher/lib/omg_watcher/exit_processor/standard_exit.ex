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

defmodule OMG.Watcher.ExitProcessor.StandardExit do
  @moduledoc """
  Part of Core to handle SE challenges & invalid exit detection.

  Treat as private helper submodule of `OMG.Watcher.ExitProcessor.Core`, test and call via that
  """

  defmodule Challenge do
    @moduledoc """
    Represents a challenge to a standard exit as returned by the `ExitProcessor`
    """
    @enforce_keys [:exit_id, :exiting_tx, :txbytes, :input_index, :sig]
    defstruct @enforce_keys

    alias OMG.Crypto
    alias OMG.State.Transaction

    @type t() :: %__MODULE__{
            exit_id: pos_integer(),
            exiting_tx: Transaction.tx_bytes(),
            txbytes: Transaction.tx_bytes(),
            input_index: non_neg_integer(),
            sig: Crypto.sig_t()
          }
  end

  alias OMG.Block
  alias OMG.State.Transaction
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.ExitProcessor.Core
  alias OMG.Watcher.ExitProcessor.DoubleSpend
  alias OMG.Watcher.ExitProcessor.ExitInfo
  alias OMG.Watcher.ExitProcessor.KnownTx
  alias OMG.Watcher.ExitProcessor.TxAppendix

  import OMG.Watcher.ExitProcessor.Tools

  @doc """
  Gets all utxo positions exiting via active standard exits
  """
  @spec exiting_positions(Core.t()) :: list(OMG.InputPointer.utxo_pos_tuple())
  def exiting_positions(%Core{} = state) do
    state
    |> active_exits()
    |> Enum.map(fn {utxo_pos, _value} -> utxo_pos end)
  end

  @doc """
  Gets all standard exits that are invalid, all and late ones separately
  """
  @spec get_invalid(Core.t(), %{OMG.InputPointer.utxo_pos_tuple() => boolean}, pos_integer()) ::
          {%{OMG.InputPointer.utxo_pos_tuple() => ExitInfo.t()}, %{OMG.InputPointer.utxo_pos_tuple() => ExitInfo.t()}}
  def get_invalid(%Core{sla_margin: sla_margin} = state, utxo_exists?, eth_height_now) do
    active_exits = active_exits(state)

    invalid_exit_positions =
      active_exits
      |> Enum.map(fn {utxo_pos, _value} -> utxo_pos end)
      |> only_utxos_checked_and_missing(utxo_exists?)

    tx_appendix = TxAppendix.get_all(state)
    exits_invalid_by_ife = get_invalid_exits_based_on_ifes(active_exits, tx_appendix)
    invalid_exits = active_exits |> Map.take(invalid_exit_positions) |> Enum.concat(exits_invalid_by_ife) |> Enum.uniq()

    # get exits which are still invalid and after the SLA margin
    late_invalid_exits =
      invalid_exits
      |> Enum.filter(fn {_, %ExitInfo{eth_height: eth_height}} -> eth_height + sla_margin <= eth_height_now end)

    {Map.new(invalid_exits), Map.new(late_invalid_exits)}
  end

  @doc """
  Determines the utxo-creating and utxo-spending blocks to get from `OMG.DB`
  `se_spending_blocks_to_get` are requested by the UTXO position they spend
  """
  @spec determine_standard_challenge_queries(ExitProcessor.Request.t(), Core.t()) ::
          {:ok, ExitProcessor.Request.t()} | {:error, :exit_not_found}
  def determine_standard_challenge_queries(
        %ExitProcessor.Request{se_exiting_pos: %OMG.InputPointer{blknum: _, txindex: _, oindex: _} = exiting_pos} =
          request,
        %Core{exits: exits} = state
      ) do
    with {:ok, _exit_info} <- get_exit(exits, exiting_pos) do
      spending_blocks_to_get = if get_ife_based_on_utxo(exiting_pos, state), do: [], else: [exiting_pos]
      {:ok, %ExitProcessor.Request{request | se_spending_blocks_to_get: spending_blocks_to_get}}
    end
  end

  @doc """
  Creates the final challenge response, if possible
  """
  @spec create_challenge(ExitProcessor.Request.t(), Core.t()) ::
          {:ok, Challenge.t()} | {:error, :utxo_not_spent}
  def create_challenge(
        %ExitProcessor.Request{se_exiting_pos: exiting_pos, se_spending_blocks_result: spending_blocks_result},
        %Core{exits: exits} = state
      )
      when not is_nil(exiting_pos) do
    %ExitInfo{owner: owner, exit_id: exit_id, exiting_txbytes: exiting_txbytes} = exits[exiting_pos]
    ife_result = get_ife_based_on_utxo(exiting_pos, state)

    with {:ok, spending_tx_or_block} <- ensure_challengeable(spending_blocks_result, ife_result) do
      %DoubleSpend{known_spent_index: input_index, known_tx: %KnownTx{signed_tx: challenging_signed}} =
        get_double_spend_for_standard_exit(spending_tx_or_block, exiting_pos)

      {:ok,
       %Challenge{
         exit_id: exit_id,
         input_index: input_index,
         exiting_tx: exiting_txbytes,
         txbytes: challenging_signed |> Transaction.raw_txbytes(),
         sig: find_sig!(challenging_signed, owner)
       }}
    end
  end

  defp ensure_challengeable(spending_blknum_response, ife_response)

  defp ensure_challengeable([%Block{} = block], _), do: {:ok, block}
  defp ensure_challengeable(_, ife_response) when not is_nil(ife_response), do: {:ok, ife_response}
  defp ensure_challengeable(_, _), do: {:error, :utxo_not_spent}

  @spec get_ife_based_on_utxo(OMG.InputPointer.utxo_pos_tuple(), Core.t()) :: KnownTx.t() | nil
  defp get_ife_based_on_utxo(%OMG.InputPointer{blknum: _, txindex: _, oindex: _} = utxo_pos, %Core{} = state) do
    state
    |> TxAppendix.get_all()
    |> get_ife_txs_by_spent_input()
    |> Map.get(utxo_pos)
    |> case do
      nil -> nil
      some -> Enum.at(some, 0)
    end
  end

  # finds transaction in given block and input index spending given utxo
  @spec get_double_spend_for_standard_exit(Block.t() | KnownTx.t(), OMG.InputPointer.utxo_pos_tuple()) ::
          DoubleSpend.t() | nil
  defp get_double_spend_for_standard_exit(%Block{transactions: txs}, utxo_pos) do
    txs
    |> Enum.map(&Transaction.Signed.decode!/1)
    |> Enum.find_value(fn tx -> get_double_spend_for_standard_exit(%KnownTx{signed_tx: tx}, utxo_pos) end)
  end

  defp get_double_spend_for_standard_exit(%KnownTx{} = known_tx, utxo_pos) do
    Enum.at(get_double_spends_by_utxo_pos(utxo_pos, known_tx), 0)
  end

  # Gets all standard exits invalidated by IFEs exiting their utxo positions
  @spec get_invalid_exits_based_on_ifes(%{OMG.InputPointer.utxo_pos_tuple() => ExitInfo.t()}, TxAppendix.t()) ::
          list({OMG.InputPointer.utxo_pos_tuple(), ExitInfo.t()})
  defp get_invalid_exits_based_on_ifes(active_exits, tx_appendix) do
    known_txs_by_input = get_ife_txs_by_spent_input(tx_appendix)
    Enum.filter(active_exits, fn {utxo_pos, _exit_info} -> Map.has_key?(known_txs_by_input, utxo_pos) end)
  end

  @spec get_double_spends_by_utxo_pos(OMG.InputPointer.utxo_pos_tuple(), KnownTx.t()) :: list(DoubleSpend.t())
  defp get_double_spends_by_utxo_pos(%OMG.InputPointer{blknum: _, txindex: _, oindex: oindex} = utxo_pos, known_tx),
    # the function used expects positions with an index (either input index or oindex), hence the oindex added
    do: [{utxo_pos, oindex}] |> double_spends_from_known_tx(known_tx)

  defp get_ife_txs_by_spent_input(tx_appendix) do
    tx_appendix
    |> Enum.map(fn signed -> %KnownTx{signed_tx: signed} end)
    |> KnownTx.group_txs_by_input()
  end

  defp get_exit(exits, exiting_pos) do
    case Map.get(exits, exiting_pos) do
      nil -> {:error, :exit_not_found}
      other -> {:ok, other}
    end
  end

  defp active_exits(%Core{exits: exits}),
    do:
      exits
      |> Enum.filter(fn {_key, %ExitInfo{is_active: is_active}} -> is_active end)
      |> Map.new()
end
