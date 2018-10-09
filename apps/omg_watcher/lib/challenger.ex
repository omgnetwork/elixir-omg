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
  alias OMG.Watcher.DB

  @doc """
  Challenges exit.
  Stub. Does nothing.
  """
  def challenge(_utxo_exit) do
    :challenged
  end

  @doc """
  Returns challenge for an exit
  """
  @spec create_challenge(Utxo.Position.t()) :: Challenge.t() | {:error, :invalid_challenge_of_exit}
  def create_challenge(utxo_exit) do
    with {:ok, challenging_tx} <- DB.Transaction.get_transaction_challenging_utxo(utxo_exit) do
      txs_in_challenging_block = DB.Transaction.get_by_blknum(challenging_tx.blknum)
      {:ok, Core.create_challenge(challenging_tx, txs_in_challenging_block)}
    else
      {:error, :utxo_not_spent} -> {:error, :invalid_challenge_of_exit}
    end
  end
end
