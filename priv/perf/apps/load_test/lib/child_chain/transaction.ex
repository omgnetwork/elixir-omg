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

  alias ChildChainAPI.Api
  alias ChildChainAPI.Model
  alias ExPlasma.Encoding
  alias ExPlasma.Transaction
  alias ExPlasma.Utxo
  alias LoadTest.Connection.ChildChain, as: Connection

  @retry_interval 1_000
  @eth <<0::160>>

  @doc """
  Spends a utxo.

  Creates, signs and submits a transaction using the utxo as the input,
  one output with the amount and receiver address and another output if there is any change.

  Returns the utxos created by the transaction. If a change utxo was created, it will be the first in the list.

  Note that input must cover fees, so the currency must be a fee paying currency.
  """
  @spec spend_utxo(
          Utxo.t(),
          pos_integer(),
          pos_integer(),
          LoadTest.Ethereum.Account.t(),
          LoadTest.Ethereum.Account.t(),
          Utxo.address_binary(),
          pos_integer()
        ) :: list(Utxo.t())
  def spend_utxo(utxo, amount, fee, signer, receiver, currency \\ @eth, retries \\ 0) do
    change_amount = utxo.amount - amount - fee
    receiver_output = %Utxo{owner: receiver.addr, currency: currency, amount: amount}
    do_spend(utxo, receiver_output, change_amount, signer, retries)
  end

  defp do_spend(_input, _output, change_amount, _signer, _retries) when change_amount < 0, do: :error_insufficient_funds

  defp do_spend(input, output, 0, signer, retries) do
    submit_tx([input], [output], [signer], retries)
  end

  defp do_spend(input, output, change_amount, signer, retries) do
    change_output = %Utxo{owner: signer.addr, currency: @eth, amount: change_amount}
    submit_tx([input], [change_output, output], [signer], retries)
  end

  @doc """
  Submits a transaction

  Creates a transaction from the given inputs and outputs, signs it and submits it to the childchain.

  Returns the utxos created by the transaction.
  """
  @spec submit_tx(
          list(Utxo.output_map()),
          list(Utxo.input_map()),
          list(LoadTest.Ethereum.Account.t()),
          pos_integer()
        ) :: list(Utxo.t())
  def submit_tx(inputs, outputs, signers, retries \\ 0) do
    {:ok, tx} = Transaction.Payment.new(%{inputs: inputs, outputs: outputs})

    keys =
      signers
      |> Enum.map(&Map.get(&1, :priv))
      |> Enum.map(&Encoding.to_hex/1)

    {:ok, blknum, txindex} =
      tx
      |> Transaction.sign(keys: keys)
      |> try_submit_tx(retries)

    outputs
    |> Enum.with_index()
    |> Enum.map(fn {output, i} ->
      %Utxo{blknum: blknum, txindex: txindex, oindex: i, amount: output.amount, currency: output.currency}
    end)
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
    body = %Model.TransactionSubmitBodySchema{
      transaction: Encoding.to_hex(encoded_tx)
    }

    Api.Transaction.submit(Connection.client(), body)
  end
end
