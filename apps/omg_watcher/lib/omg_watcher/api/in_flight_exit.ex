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

defmodule OMG.Watcher.API.InFlightExit do
  @moduledoc """
  Module provides API for starting, validating and challenging in-flight exits
  """

  alias OMG.State.Transaction
  alias OMG.Utxo
  alias OMG.Watcher.API
  alias OMG.Watcher.ExitProcessorDispatcher

  require Utxo

  @type in_flight_exit() :: %{
          in_flight_tx: binary(),
          input_txs: list(binary()),
          input_txs_inclusion_proofs: list(binary()),
          in_flight_tx_sigs: list(binary())
        }

  @doc """
  Returns arguments for plasma contract function that starts in-flight exit for a given transaction.
  """
  @spec get_in_flight_exit(binary) :: {:ok, in_flight_exit()} | {:error, atom}
  def get_in_flight_exit(txbytes) do
    with {:ok, tx} <- Transaction.Signed.decode(txbytes),
         {:ok, {proofs, input_txs, input_utxos_pos}} <- find_input_data(tx) do
      %Transaction.Signed{sigs: sigs} = tx

      {:ok,
       %{
         in_flight_tx: Transaction.raw_txbytes(tx),
         input_txs: input_txs,
         input_utxos_pos: input_utxos_pos,
         input_txs_inclusion_proofs: proofs,
         in_flight_tx_sigs: sigs
       }}
    end
  end

  @doc """
  Returns arguments for plasma contract function that challenges a non-canonical IFE with a competitor for a given
  in-flight-exiting transaction.

  This delegates directly to `OMG.Watcher.ExitProcessor` see there for details
  """
  def get_competitor(txbytes) do
    ExitProcessorDispatcher.get_competitor_for_ife(txbytes)
  end

  @doc """
  Returns arguments for plasma contract function that responds to a challeng to an IFE with an inclusion proof

  This delegates directly to `OMG.Watcher.ExitProcessor` see there for details
  """
  def prove_canonical(txbytes) do
    ExitProcessorDispatcher.prove_canonical_for_ife(txbytes)
  end

  @doc """
  Returns arguments for plasma contract function proving that input was double-signed in some other IFE.

  This delegates directly to `OMG.Watcher.ExitProcessor` see there for details
  """
  def get_input_challenge_data(txbytes, input_index) do
    ExitProcessorDispatcher.get_input_challenge_data(txbytes, input_index)
  end

  @doc """
  Returns arguments for plasma contract function proving that output was double-spent in other IFE or block.

  This delegates directly to `OMG.Watcher.ExitProcessor` see there for details
  """
  def get_output_challenge_data(txbytes, output_index) do
    ExitProcessorDispatcher.get_output_challenge_data(txbytes, output_index)
  end

  defp find_input_data(tx) do
    tx
    |> Transaction.get_inputs()
    # reversing to preserve the order of inputs, the `reduce_while` builds 3 lists by prepending
    |> Enum.reverse()
    |> Enum.reduce_while({:ok, {[], [], []}}, &find_single_input_data/2)
  end

  defp find_single_input_data(input_utxo_pos, {:ok, {proofs, txbyteses, utxo_positions}}) do
    input_utxo_pos
    |> API.Utxo.compose_utxo_exit()
    |> case do
      {:ok, %{proof: proof, txbytes: txbytes}} ->
        utxo_pos = Utxo.Position.encode(input_utxo_pos)
        {:cont, {:ok, {[proof | proofs], [txbytes | txbyteses], [utxo_pos | utxo_positions]}}}

      {:error, :utxo_not_found} ->
        {:halt, {:error, :tx_for_input_not_found}}

      {:error, :no_deposit_for_given_blknum} ->
        {:halt, {:error, :deposit_input_spent_ife_unsupported}}
    end
  end
end
