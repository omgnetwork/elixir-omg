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
defmodule LoadTest.ChildChain.Transaction do
  @moduledoc """
  Utility functions for sending transaction to child chain
  """
  require Logger

  alias ExPlasma.Encoding
  alias ExPlasma.Transaction

  @retry_interval 1_000

  def submit_tx(inputs, outputs, signers, retries \\ 0) do
    {:ok, tx} = Transaction.Payment.new(%{inputs: inputs, outputs: outputs})

    keys =
      signers
      |> Enum.map(&Map.get(&1, :priv))
      |> Enum.map(&Encoding.to_hex/1)

    tx
    |> Transaction.sign(keys: keys)
    |> try_submit_tx(retries)
  end

  defp try_submit_tx(tx, 0), do: do_submit_tx(tx)

  defp try_submit_tx(tx, retries) do
    case do_submit_tx(tx) do
      {:error, "submit:utxo_not_found"} ->
        Process.sleep(@retry_interval)
        try_submit_tx(tx, retries - 1)

      result ->
        result
    end
  end

  defp do_submit_tx(tx) do
    {:ok, response} =
      tx
      |> Transaction.encode()
      |> do_submit_tx_rpc()

    response
    |> Map.fetch!(:body)
    |> Jason.decode!()
    |> Map.fetch!("data")
    |> case do
      %{"blknum" => blknum, "txindex" => txindex} ->
        _ = Logger.debug("[Transaction submitted successfully {#{inspect(blknum)}, #{inspect(txindex)}}")
        {:ok, blknum, txindex}

      %{"code" => reason} ->
        _ = Logger.warn("Transaction submission has failed, reason: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @spec do_submit_tx_rpc(binary) :: {:ok, map} | {:error, any}
  defp do_submit_tx_rpc(encoded_tx) do
    connection = LoadTest.Connection.ChildChain.client()

    body = %ChildChainAPI.Model.TransactionSubmitBodySchema{
      transaction: Encoding.to_hex(encoded_tx)
    }

    ChildChainAPI.Api.Transaction.submit(connection, body)
  end
end
