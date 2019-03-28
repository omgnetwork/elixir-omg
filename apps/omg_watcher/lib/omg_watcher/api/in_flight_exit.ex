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

defmodule OMG.Watcher.API.InFlightExit do
  @moduledoc """
  Module provides API for transactions
  """

  alias OMG.State.Transaction
  alias OMG.Utxo
  alias OMG.Watcher.DB
  alias OMG.Watcher.ExitProcessor

  require Utxo

  @type in_flight_exit() :: %{
          in_flight_tx: binary(),
          input_txs: binary(),
          input_txs_inclusion_proofs: binary(),
          in_flight_tx_sigs: binary()
        }

  @doc """
  Returns arguments for plasma contract function that starts in-flight exit for a given transaction.
  """
  @spec get_in_flight_exit(binary) :: {:ok, in_flight_exit()} | {:error, atom}
  def get_in_flight_exit(txbytes) do
    with {:ok, tx} <- Transaction.Signed.decode(txbytes),
         {:ok, {proofs, input_txs}} <- find_input_data(tx) do
      %Transaction.Signed{raw_tx: raw_tx, sigs: sigs} = tx

      raw_txbytes = Transaction.encode(raw_tx)
      input_txs = get_input_txs_for_rlp_encoding(input_txs)
      sigs = Enum.join(sigs)
      proofs = Enum.join(proofs)

      {:ok,
       %{
         in_flight_tx: raw_txbytes,
         input_txs: ExRLP.encode(input_txs),
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
    ExitProcessor.get_competitor_for_ife(txbytes)
  end

  @doc """
  Returns arguments for plasma contract function that responds to a challeng to an IFE with an inclusion proof

  This delegates directly to `OMG.Watcher.ExitProcessor` see there for details
  """
  def prove_canonical(txbytes) do
    ExitProcessor.prove_canonical_for_ife(txbytes)
  end

  @doc """
  Returns arguments for plasma contract function proving that input was double-signed in some other IFE.

  This delegates directly to `OMG.Watcher.ExitProcessor` see there for details
  """
  def get_input_challenge_data(txbytes, input_index) do
    ExitProcessor.get_input_challenge_data(txbytes, input_index)
  end

  @doc """
  Returns arguments for plasma contract function proving that output was double-spent in other IFE or block.

  This delegates directly to `OMG.Watcher.ExitProcessor` see there for details
  """
  def get_output_challenge_data(txbytes, output_index) do
    ExitProcessor.get_output_challenge_data(txbytes, output_index)
  end

  defp find_input_data(%Transaction.Signed{raw_tx: raw_tx}) do
    result =
      raw_tx
      |> Transaction.get_inputs()
      |> Enum.map(fn
        Utxo.position(0, 0, 0) ->
          {<<>>, <<>>}

        utxo_pos ->
          with {:ok, %{proof: proof, txbytes: txbytes}} <- DB.TxOutput.compose_utxo_exit(utxo_pos),
               do: {proof, txbytes}
      end)

    result
    |> Enum.any?(&match?({:error, :utxo_not_found}, &1))
    |> case do
      true -> {:error, :tx_for_input_not_found}
      false -> {:ok, Enum.unzip(result)}
    end
  end

  defp get_input_txs_for_rlp_encoding(input_txs) do
    input_txs
    |> Enum.map(&ExRLP.decode/1)
    |> Enum.map(fn
      nil -> ""
      input_tx -> input_tx
    end)
  end
end
