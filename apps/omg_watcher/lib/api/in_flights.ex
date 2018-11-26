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

defmodule OMG.Watcher.API.InFlights do
  @moduledoc """
  A convenience bucket to separate out all `OMG.Watcher.API` calls related to in-flight stuff (MoreVP)
  """

  alias OMG.API.State.Transaction
  alias OMG.API.Utxo
  alias OMG.DB
  alias OMG.Watcher.DB

  require Utxo

  @doc """
  see `OMG.Watcher.API.get_in_flight_exit/1`
  """
  def get_in_flight_exit(tx) do
    with {:ok, recovered_tx} <- OMG.API.Core.recover_tx(tx),
         {:ok, {proofs, input_txs}} <- find_input_data(recovered_tx) do
      %Transaction.Recovered{signed_tx: %Transaction.Signed{raw_tx: raw_tx, sig1: sig1, sig2: sig2}} = recovered_tx
      raw_tx_bytes = Transaction.encode(raw_tx)

      {:ok,
       %{
         in_flight_tx: raw_tx_bytes,
         input_txs: Enum.join(input_txs),
         input_txs_inclusion_proofs: Enum.join(proofs),
         in_flight_tx_sigs: sig1 <> sig2
       }}
    end
  end

  defp find_input_data(recovered_tx) do
    result =
      recovered_tx
      |> get_inputs()
      |> Enum.map(fn {blknum, txindex} ->
        with {:ok, %{proof: proof, txbytes: txbytes}} <-
               DB.TxOutput.compose_utxo_exit(Utxo.position(blknum, txindex, 0)),
             do: {proof, txbytes}
      end)

    result
    |> Enum.any?(&match?({:error, :no_tx_for_given_blknum}, &1))
    |> case do
      true -> {:error, :tx_for_input_not_found}
      false -> {:ok, Enum.unzip(result)}
    end
  end

  defp get_inputs(%Transaction.Recovered{
         signed_tx: %Transaction.Signed{
           raw_tx: %Transaction{blknum1: blknum1, txindex1: txindex1, blknum2: blknum2, txindex2: txindex2}
         }
       }) do
    # FIXME: use Transaction public api instead, when it lands
    [{blknum1, txindex1}, {blknum2, txindex2}]
    |> Enum.filter(&match?({blknum, _} when blknum != 0, &1))
  end
end
