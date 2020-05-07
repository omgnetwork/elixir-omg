# Copyright 2019-2020 OmiseGO Pte Ltd
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
  alias OMG.Utxo
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.ExitProcessor.Core
  alias OMG.Watcher.ExitProcessor.DoubleSpend
  alias OMG.Watcher.ExitProcessor.ExitInfo
  alias OMG.Watcher.ExitProcessor.KnownTx
  alias OMG.Watcher.ExitProcessor.TxAppendix

  import OMG.Watcher.ExitProcessor.Tools

  require Utxo

  @doc """
  Gets all utxo positions exiting via active standard exits
  """
  @spec exiting_positions(Core.t()) :: list(Utxo.Position.t())
  def exiting_positions(%Core{} = state) do
    state
    |> active_exits()
    |> Enum.map(fn {utxo_pos, _value} -> utxo_pos end)
  end

  @doc """
  Gets all standard exits that are invalid, all and late ones separately, also adds their :spending_txhash
  """
  @spec get_invalid(Core.t(), %{Utxo.Position.t() => boolean}, pos_integer()) ::
          {%{Utxo.Position.t() => ExitInfo.t()}, %{Utxo.Position.t() => ExitInfo.t()}}
  def get_invalid(%Core{sla_margin: sla_margin} = state, utxo_exists?, eth_height_now) do
    active_exits = active_exits(state)

    exits_invalid_by_ife =
      state
      |> TxAppendix.get_all()
      |> get_invalid_exits_based_on_ifes(active_exits)

    invalid_exit_positions =
      active_exits
      |> Enum.map(fn {utxo_pos, _value} -> utxo_pos end)
      |> only_utxos_checked_and_missing(utxo_exists?)

    standard_invalid_exits =
      active_exits
      |> Map.take(invalid_exit_positions)
      |> Enum.map(fn {utxo_pos, invalid_exit} ->
        spending_txhash = spending_txhash_for_exit_at(utxo_pos)

        {utxo_pos, %{invalid_exit | spending_txhash: spending_txhash}}
      end)

    invalid_exits = standard_invalid_exits |> Enum.concat(exits_invalid_by_ife) |> Enum.uniq()

    # get exits which are still invalid and after the SLA margin
    late_invalid_exits =
      Enum.filter(invalid_exits, fn {_, %ExitInfo{eth_height: eth_height}} ->
        eth_height + sla_margin <= eth_height_now
      end)

    {Map.new(invalid_exits), Map.new(late_invalid_exits)}
  end

  defp spending_txhash_for_exit_at(utxo_pos) do
    utxo_pos
    |> Utxo.Position.to_input_db_key()
    |> OMG.DB.spent_blknum()
    |> List.wrap()
    |> Core.handle_spent_blknum_result([utxo_pos])
    |> do_get_blocks()
    |> case do
      [block] ->
        %DoubleSpend{known_tx: %KnownTx{signed_tx: spending_tx}} = get_double_spend_for_standard_exit(block, utxo_pos)
        Transaction.raw_txhash(spending_tx)

      _ ->
        nil
    end
  end

  defp do_get_blocks(blknums) do
    {:ok, hashes} = OMG.DB.block_hashes(blknums)
    {:ok, blocks} = OMG.DB.blocks(hashes)

    Enum.map(blocks, &Block.from_db_value/1)
  end

  @doc """
  Determines the utxo-creating and utxo-spending blocks to get from `OMG.DB`
  `se_spending_blocks_to_get` are requested by the UTXO position they spend
  """
  @spec determine_standard_challenge_queries(ExitProcessor.Request.t(), Core.t(), boolean()) ::
          {:ok, ExitProcessor.Request.t()} | {:error, :exit_not_found | :utxo_not_spent}
  def determine_standard_challenge_queries(
        %ExitProcessor.Request{se_exiting_pos: Utxo.position(_, _, _) = exiting_pos} = request,
        %Core{exits: exits} = state,
        exiting_utxo_exists
      ) do
    with {:ok, _exit_info} <- get_exit(exits, exiting_pos),
         # once figured out the exit exists, check if it is spent in an IFE?
         ife_based_on_utxo = get_ife_based_on_utxo(exiting_pos, state),
         # To be challengable, the exit utxo must be spent in either an IFE or missing from the `OMG.State`.
         # In the latter case we'll go on looking for the spending tx in the `OMG.DB`
         true <- !is_nil(ife_based_on_utxo) || !exiting_utxo_exists || {:error, :utxo_not_spent} do
      # if the exit utxo is spent in an IFE no need to bother with looking for the spending tx in the blocks
      spending_blocks_to_get = if ife_based_on_utxo, do: [], else: [exiting_pos]

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

  @spec get_ife_based_on_utxo(Utxo.Position.t(), Core.t()) :: KnownTx.t() | nil
  defp get_ife_based_on_utxo(Utxo.position(_, _, _) = utxo_pos, %Core{} = state) do
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
  @spec get_double_spend_for_standard_exit(Block.t() | KnownTx.t(), Utxo.Position.t()) :: DoubleSpend.t() | nil
  defp get_double_spend_for_standard_exit(%Block{transactions: txs}, utxo_pos) do
    txs
    |> Enum.map(&Transaction.Signed.decode!/1)
    |> Enum.find_value(fn tx -> get_double_spend_for_standard_exit(%KnownTx{signed_tx: tx}, utxo_pos) end)
  end

  defp get_double_spend_for_standard_exit(%KnownTx{} = known_tx, utxo_pos) do
    Enum.at(get_double_spends_by_utxo_pos(utxo_pos, known_tx), 0)
  end

  # Gets all standard exits invalidated by IFEs exiting their utxo positions and append the spending_txhash
  @spec get_invalid_exits_based_on_ifes(TxAppendix.t(), %{Utxo.Position.t() => ExitInfo.t()}) ::
          list({Utxo.Position.t(), ExitInfo.t()})
  defp get_invalid_exits_based_on_ifes(tx_appendix, active_exits) do
    known_txs_by_input = get_ife_txs_by_spent_input(tx_appendix)

    active_exits
    |> Enum.filter(fn {utxo_pos, _exit_info} -> Map.has_key?(known_txs_by_input, utxo_pos) end)
    |> Enum.map(fn {utxo_pos, exit_info} ->
      spending_txhash =
        known_txs_by_input
        |> Map.get(utxo_pos)
        |> Enum.at(0)
        |> Map.get(:signed_tx)
        |> Transaction.raw_txhash()

      {utxo_pos, %{exit_info | spending_txhash: spending_txhash}}
    end)
  end

  @spec get_double_spends_by_utxo_pos(Utxo.Position.t(), KnownTx.t()) :: list(DoubleSpend.t())
  defp get_double_spends_by_utxo_pos(Utxo.position(_, _, oindex) = utxo_pos, known_tx),
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
