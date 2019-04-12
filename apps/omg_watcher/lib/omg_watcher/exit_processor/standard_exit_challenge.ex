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

defmodule OMG.Watcher.ExitProcessor.StandardExitChallenge do
  @moduledoc """
  Part of Core to handle SE challenges
  """

  # struct Represents a challenge to a standard exit
  defstruct [:exit_id, :txbytes, :input_index, :sig]

  @type t() :: %__MODULE__{
          exit_id: non_neg_integer(),
          txbytes: String.t(),
          input_index: non_neg_integer(),
          sig: String.t()
        }

  alias OMG.Block
  alias OMG.State.Transaction
  alias OMG.Utxo
  require Utxo
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.ExitProcessor.Core
  alias OMG.Watcher.ExitProcessor.ExitInfo
  alias OMG.Watcher.ExitProcessor.TxAppendix

  @doc """
  Determines the utxo-creating and utxo-spending blocks to get from `OMG.DB`
  `se_spending_blocks_to_get` are requested by the UTXO position they spend
  `se_creating_blocks_to_get` are requested by blknum
  """
  @spec determine_standard_challenge_queries(ExitProcessor.Request.t(), Core.t()) :: ExitProcessor.Request.t()
  def determine_standard_challenge_queries(
        %ExitProcessor.Request{se_exiting_pos: Utxo.position(creating_blknum, _, _) = exiting_pos} = request,
        %Core{exits: exits} = state
      ) do
    with %ExitInfo{} = _exit_info <- Map.get(exits, exiting_pos, {:error, :exit_not_found}) do
      spending_blocks_to_get = if get_ife_based_on_utxo(exiting_pos, state), do: [], else: [exiting_pos]
      creating_blocks_to_get = if Utxo.Position.is_deposit?(exiting_pos), do: [], else: [creating_blknum]

      %ExitProcessor.Request{
        request
        | se_spending_blocks_to_get: spending_blocks_to_get,
          se_creating_blocks_to_get: creating_blocks_to_get
      }
    end
  end

  @doc """
  Determines the txbytes of the particular transaction related to the SE - aka "output tx" - which creates the exiting
  utxo
  """
  @spec determine_exit_txbytes(ExitProcessor.Request.t(), Core.t()) ::
          ExitProcessor.Request.t()
  def determine_exit_txbytes(
        %ExitProcessor.Request{se_exiting_pos: exiting_pos, se_creating_blocks_result: creating_blocks_result} =
          request,
        %Core{exits: exits}
      ) do
    exit_id_to_get_by_txbytes =
      if Utxo.Position.is_deposit?(exiting_pos) do
        %ExitInfo{owner: owner, currency: currency, amount: amount} = exits[exiting_pos]
        Transaction.new([], [{owner, currency, amount}])
      else
        [%Block{transactions: transactions}] = creating_blocks_result
        Utxo.position(_, txindex, _) = exiting_pos

        {:ok, signed_bytes} = Enum.fetch(transactions, txindex)
        {:ok, tx} = Transaction.Signed.decode(signed_bytes)
        tx
      end
      |> Transaction.raw_txbytes()

    %ExitProcessor.Request{request | se_exit_id_to_get: exit_id_to_get_by_txbytes}
  end

  @doc """
  Creates the final challenge response, if possible
  """
  @spec create_challenge(ExitProcessor.Request.t(), Core.t()) ::
          {:ok, __MODULE__.t()} | {:error, :utxo_not_spent} | {:error, :exit_not_found}
  def create_challenge(
        %ExitProcessor.Request{
          se_exiting_pos: exiting_pos,
          se_spending_blocks_result: spending_blocks_result,
          se_exit_id_result: exit_id
        },
        %Core{exits: exits} = state
      ) do
    %ExitInfo{owner: owner} = exits[exiting_pos]
    ife_result = get_ife_based_on_utxo(exiting_pos, state)

    with {:ok, spending_tx_or_block} <- ensure_challengeable(spending_blocks_result, ife_result) do
      {challenging_signed, input_index} = get_spending_transaction_with_index(spending_tx_or_block, exiting_pos)

      {:ok,
       %__MODULE__{
         exit_id: exit_id,
         input_index: input_index,
         txbytes: challenging_signed |> Transaction.raw_txbytes(),
         sig: Core.find_sig!(challenging_signed, owner)
       }}
    end
  end

  defp ensure_challengeable(spending_blknum_response, ife_response)

  defp ensure_challengeable([%Block{} = block], _), do: {:ok, block}
  defp ensure_challengeable(_, ife_response) when not is_nil(ife_response), do: {:ok, ife_response}
  defp ensure_challengeable(_, _), do: {:error, :utxo_not_spent}

  @spec get_ife_based_on_utxo(Utxo.Position.t(), Core.t()) :: Transaction.Signed.t() | nil
  defp get_ife_based_on_utxo(Utxo.position(_, _, _) = utxo_exit, %Core{} = state) do
    state
    |> TxAppendix.get_all()
    |> Enum.find(&Enum.member?(Transaction.get_inputs(&1), utxo_exit))
  end

  # finds transaction in given block and input index spending given utxo
  @spec get_spending_transaction_with_index(Block.t() | Transaction.Signed.t(), Utxo.Position.t()) ::
          {Transaction.Signed.t(), non_neg_integer()} | nil
  defp get_spending_transaction_with_index(%Block{transactions: txs}, utxo_pos) do
    txs
    |> Enum.map(&Transaction.Signed.decode/1)
    |> Enum.find_value(fn {:ok, tx_signed} ->
      # `Enum.find_value/2` allows to find tx that spends `utxo_pos` and return it along with input index in one run
      get_spending_transaction_with_index(tx_signed, utxo_pos)
    end)
  end

  defp get_spending_transaction_with_index(tx, utxo_pos) do
    inputs = Transaction.get_inputs(tx)

    if input_index = Enum.find_index(inputs, &(&1 == utxo_pos)) do
      {tx, input_index}
    else
      nil
    end
  end
end
