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

defmodule OMG.Watcher.API.Utxo do
  @moduledoc """
  Module provides API for utxos
  """
  alias OMG.Utxo
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.UtxoExit.Core

  use Spandex.Decorators
  require Utxo
  import Utxo, only: [is_deposit: 1]

  @type exit_t() :: %{
          utxo_pos: pos_integer(),
          txbytes: binary(),
          proof: binary(),
          sigs: binary()
        }

  @doc """
  Returns a proof that utxo was spent
  """

  @spec create_challenge(Utxo.Position.t()) ::
          {:ok, ExitProcessor.StandardExit.Challenge.t()} | {:error, :utxo_not_spent} | {:error, :exit_not_found}
  def create_challenge(utxo) do
    ExitProcessor.create_challenge(utxo)
  end

  @spec compose_utxo_exit(Utxo.Position.t()) :: {:ok, exit_t()} | {:error, :utxo_not_found}
  def compose_utxo_exit(utxo_pos) when is_deposit(utxo_pos) do
    OMG.DB.utxos() |> Core.get_deposit_utxo(utxo_pos) |> Core.compose_deposit_exit(utxo_pos)
  end

  def compose_utxo_exit(Utxo.position(blknum, _, _) = utxo_pos) do
    with {:ok, blk_hashes} <- OMG.DB.block_hashes([blknum]),
         {:ok, [%{transactions: transactions}]} <- OMG.DB.blocks(blk_hashes) do
      Core.compose_output_exit(transactions, utxo_pos)
    else
      _error -> {:error, :utxo_not_found}
    end
  end
end
