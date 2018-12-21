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

defmodule OMG.Watcher.API.Transaction do
  @moduledoc """
  Module provides API for transactions
  """

  alias OMG.API.State.Transaction
  alias OMG.API.Utxo
  alias OMG.Watcher.DB

  require Utxo

  @type in_flight_exit() :: %{
          in_flight_tx: binary(),
          input_txs: binary(),
          input_txs_inclusion_proofs: binary(),
          in_flight_tx_sigs: binary()
        }

  @doc """
  Retrieves a specific transaction by id
  """
  @spec get(binary()) :: nil | %DB.Transaction{}
  def get(transaction_id) do
    DB.Transaction.get(transaction_id, true)
  end

  @doc """
  Retrieves a list of transactions that a given address is involved as input or output owner.
  Length of the list is limited by `limit` argument.
  If `nil` is given as `address` argument then a list of last 'limit' transactions is returned.
  """
  @spec get_transactions(nil | OMG.API.Crypto.address_t(), pos_integer()) :: list(%DB.Transaction{})
  def get_transactions(nil, limit), do: DB.Transaction.get_last(limit)

  def get_transactions(address, limit), do: DB.Transaction.get_by_address(address, limit)

  @doc """
  Returns arguments for function that starts in-flight exit on a root chain.
  """
  @spec get_in_flight_exit(%Transaction.Signed{}) :: {:ok, in_flight_exit()} | {:error, atom}
  def get_in_flight_exit(tx) do
    with {:ok, {proofs, input_txs}} <- find_input_data(tx) do
      %Transaction.Signed{raw_tx: raw_tx, sigs: sigs} = tx

      raw_tx_bytes = Transaction.encode(raw_tx)

      input_txs =
        input_txs
        |> Enum.map(&ExRLP.decode/1)
        |> Enum.map(fn
          nil -> ""
          input_tx -> input_tx
        end)

      sigs = Enum.reduce(sigs, fn sig, acc -> acc <> sig end)
      proofs = Enum.reduce(proofs, fn proof, acc -> acc <> proof end)

      {:ok,
       %{
         in_flight_tx: raw_tx_bytes,
         input_txs: ExRLP.encode(input_txs),
         input_txs_inclusion_proofs: proofs,
         in_flight_tx_sigs: sigs
       }}
    end
  end

  defp find_input_data(%Transaction.Signed{raw_tx: raw_tx}) do
    result =
      raw_tx
      |> Transaction.get_inputs()
      |> Enum.map(fn utxo_pos ->
        case utxo_pos do
          Utxo.position(0, 0, 0) ->
            {<<>>, <<>>}

          _ ->
            with {:ok, %{proof: proof, txbytes: txbytes}} <- DB.TxOutput.compose_utxo_exit(utxo_pos),
                 do: {proof, txbytes}
        end
      end)

    result
    |> Enum.any?(&match?({:error, :utxo_not_found}, &1))
    |> case do
      true -> {:error, :tx_for_input_not_found}
      false -> {:ok, Enum.unzip(result)}
    end
  end
end
