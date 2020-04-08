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

defmodule OMG.Watcher.API.Utxo do
  @moduledoc """
  Module provides API for utxos
  """

  alias OMG.Eth.Configuration
  alias OMG.Utxo
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.UtxoExit.Core

  require Utxo

  @type exit_t() :: %{
          utxo_pos: pos_integer(),
          txbytes: binary(),
          proof: binary(),
          sigs: binary()
        }

  @interval Configuration.child_block_interval()

  # Based on the contract parameters determines whether UTXO position provided was created by a deposit
  defguardp is_deposit(blknum) when rem(blknum, @interval) != 0

  @doc """
  Returns a proof that utxo was spent
  """
  @spec create_challenge(Utxo.Position.t()) ::
          {:ok, ExitProcessor.StandardExit.Challenge.t()} | {:error, :utxo_not_spent} | {:error, :exit_not_found}
  def create_challenge(utxo) do
    ExitProcessor.create_challenge(utxo)
  end

  @spec compose_utxo_exit(Utxo.Position.t()) ::
          {:ok, exit_t()} | {:error, :utxo_not_found} | {:error, :no_deposit_for_given_blknum}
  def compose_utxo_exit(Utxo.position(blknum, _, _) = utxo_pos) when is_deposit(blknum) do
    utxo_pos |> Utxo.Position.to_input_db_key() |> OMG.DB.utxo() |> Core.compose_deposit_standard_exit()
  end

  def compose_utxo_exit(Utxo.position(blknum, _, _) = utxo_pos) do
    with {:ok, [blk_hash]} <- OMG.DB.block_hashes([blknum]),
         {:ok, [db_block]} <- OMG.DB.blocks([blk_hash]) do
      Core.compose_block_standard_exit(db_block, utxo_pos)
    else
      _error -> {:error, :utxo_not_found}
    end
  end
end
