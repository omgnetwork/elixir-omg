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

defmodule OMG.Watcher.API.Utxo do
  @moduledoc """
  Module provides API for utxos
  """

  alias OMG.Utxo
  alias OMG.Watcher.DB
  alias OMG.Watcher.ExitProcessor

  @doc """
  Returns exit data for an utxo
  TODO: For now uses Postgres data, but should be adapted to OMG.DB (in security-critical only mode)
  """
  @spec compose_utxo_exit(Utxo.Position.t()) :: {:ok, DB.TxOutput.exit_t()} | {:error, :utxo_not_found}
  def compose_utxo_exit(utxo) do
    DB.TxOutput.compose_utxo_exit(utxo)
  end

  @doc """
  Returns a proof that utxo was spent
  """
  @spec create_challenge(Utxo.Position.t()) ::
          {:ok, ExitProcessor.Challenge.t()} | {:error, :utxo_not_spent} | {:error, :exit_not_found}
  def create_challenge(utxo) do
    ExitProcessor.create_challenge(utxo)
  end
end
