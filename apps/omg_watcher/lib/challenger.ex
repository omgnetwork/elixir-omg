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

defmodule OMG.Watcher.Challenger do
  @moduledoc """
  Manages challenges of exits
  """

  alias OMG.API.Utxo
  require Utxo
  alias OMG.Watcher.Challenger.Challenge
  alias OMG.Watcher.Challenger.Core

  @doc """
  Returns challenge for an exit
  """
  @spec create_challenge(Utxo.Position.t()) ::
          {:ok, Challenge.t()} | {:error, :utxo_not_spent} | {:error, :exit_not_found}
  def create_challenge(Utxo.position(blknum, txindex, oindex) = exiting_utxo_pos) do
    with spending_blknum_response = OMG.DB.spent_blknum({blknum, txindex, oindex}),
         exit_response = OMG.DB.exit_info({blknum, txindex, oindex}),
         {:ok, spending_blknum, exit_info} <- Core.ensure_challengeable(spending_blknum_response, exit_response) do
      {:ok, hashes} = OMG.DB.block_hashes([spending_blknum])
      {:ok, [spending_block]} = OMG.DB.blocks(hashes)
      {:ok, Core.create_challenge(exit_info, spending_block, exiting_utxo_pos)}
    end
  end
end
