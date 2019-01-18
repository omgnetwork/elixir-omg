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

defmodule OMG.Watcher.Challenger.Core do
  @moduledoc """
  Functional core of challenger
  """

  alias OMG.API.Block
  alias OMG.API.State.Transaction
  alias OMG.API.Utxo
  alias OMG.Watcher.Challenger.Challenge
  alias OMG.Watcher.Challenger.Tools
  alias OMG.Watcher.ExitProcessor.ExitInfo

  require Utxo

  @doc """
  Creates a challenge for exiting utxo.
  """
  @spec create_challenge(map, Block.t(), Utxo.Position.t()) :: Challenge.t()
  def create_challenge(%{owner: owner}, spending_block, Utxo.position(_, _, _) = utxo_exit) do
    {%Transaction.Signed{raw_tx: challenging_tx} = challenging_signed, input_index} =
      get_spending_transaction_with_index(spending_block, utxo_exit)

    %Challenge{
      output_id: Utxo.Position.encode(utxo_exit),
      input_index: input_index,
      txbytes: challenging_tx |> Transaction.encode(),
      sig: find_sig(challenging_signed, owner)
    }
  end

  @doc """
  Checks whether database responses hold all the relevant data succesfully fetched:
   - a block number which can be used to retrieve needed information to challenge.
   - the relevant exit information
  """
  @spec ensure_challengeable(tuple(), tuple()) :: {:ok, pos_integer(), ExitInfo.t()} | {:error, atom()}
  def ensure_challengeable(spending_blknum_response, exit_response)

  def ensure_challengeable({:ok, :not_found}, _), do: {:error, :utxo_not_spent}
  def ensure_challengeable(_, {:ok, :not_found}), do: {:error, :exit_not_found}

  def ensure_challengeable({:ok, blknum}, {:ok, {_, exit_info}}) when is_integer(blknum),
    do: {:ok, blknum, exit_info}

  def ensure_challengeable({:error, error}, _), do: {:error, error}
  def ensure_challengeable(_, {:error, error}), do: {:error, error}

  # finds transaction in given block and input index spending given utxo
  @spec get_spending_transaction_with_index(Block.t(), Utxo.Position.t()) ::
          {Transaction.Signed.t(), non_neg_integer()} | false
  defp get_spending_transaction_with_index(%Block{transactions: txs}, utxo_pos) do
    txs
    |> Enum.map(&Transaction.Signed.decode/1)
    |> Enum.find_value(fn {:ok, %Transaction.Signed{raw_tx: tx} = tx_signed} ->
      # `Enum.find_value/2` allows to find tx that spends `utxo_pos` and return it along with input index in one run
      inputs = Transaction.get_inputs(tx)

      if input_index = Enum.find_index(inputs, &(&1 == utxo_pos)) do
        {tx_signed, input_index}
      else
        false
      end
    end)
  end

  defp find_sig(tx, owner) do
    # at this point having a tx that wasn't actually signed is an error, hence pattern match
    {:ok, sig} = Tools.find_sig(tx, owner)
    sig
  end
end
