# Copyright 2019-2020 OMG Network Pte Ltd
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
  alias LoadTest.Service.Metrics
  alias LoadTest.Service.Sync

  # safe, reasonable amount, equal to the testnet block gas limit
  @lots_of_gas 5_712_388
  @gas_price 1_000_000_000

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
  def spend_utxo(utxo, amount, fee, signer, receiver, currency, retries \\ 120_000)

  def spend_utxo(utxo, amount, fee, signer, receiver, currency, timeout) when byte_size(currency) == 20 do
    change_amount = utxo.amount - amount - fee
    receiver_output = %Utxo{owner: receiver.addr, currency: currency, amount: amount}
    do_spend(utxo, receiver_output, change_amount, currency, signer, timeout)
  end

  def spend_utxo(utxo, amount, fee, signer, receiver, currency, timeout) do
    spend_utxo(utxo, amount, fee, signer, receiver, Encoding.to_binary(currency), timeout)
  end

  def tx_defaults() do
    Enum.map([value: 0, gasPrice: @gas_price, gas: @lots_of_gas], fn {k, v} -> {k, Encoding.to_hex(v)} end)
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
  def submit_tx(inputs, outputs, signers, retries \\ 120_000) do
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

  def recover(encoded_signed_tx) do
    {:ok, trx} =
      encoded_signed_tx
      |> Encoding.to_binary()
      |> ExRLP.decode()
      |> reconstruct()

    trx
  end

  defp reconstruct([raw_witnesses | typed_tx_rlp_decoded_chunks]) do
    with true <- is_list(raw_witnesses) || {:error, :malformed_witnesses},
         true <- Enum.all?(raw_witnesses, &valid_witness?/1) || {:error, :malformed_witnesses},
         {:ok, raw_tx} <- reconstruct_transaction(typed_tx_rlp_decoded_chunks) do
      {:ok, %{raw_tx: raw_tx, sigs: raw_witnesses}}
    end
  end

  defp do_spend(_input, _output, change_amount, _currency, _signer, _retries) when change_amount < 0 do
    :error_insufficient_funds
  end

  defp do_spend(input, output, 0, _currency, signer, retries) do
    submit_tx([input], [output], [signer], retries)
  end

  defp do_spend(input, output, change_amount, currency, signer, retries) do
    change_output = %Utxo{owner: signer.addr, currency: currency, amount: change_amount}
    submit_tx([input], [change_output, output], [signer], retries)
  end

  defp valid_witness?(witness) when is_binary(witness), do: byte_size(witness) == 65
  defp valid_witness?(_), do: false

  defp reconstruct_transaction([raw_type, inputs_rlp, outputs_rlp, tx_data_rlp, metadata_rlp])
       when is_binary(raw_type) do
    with {:ok, 1} <- parse_uint256(raw_type),
         {:ok, inputs} <- parse_inputs(inputs_rlp),
         {:ok, outputs} <- parse_outputs(outputs_rlp),
         {:ok, tx_data} <- parse_uint256(tx_data_rlp),
         0 <- tx_data,
         {:ok, metadata} <- validate_metadata(metadata_rlp) do
      {:ok, %{tx_type: 1, inputs: inputs, outputs: outputs, metadata: metadata}}
    else
      _ -> {:error, :unrecognized_transaction_type}
    end
  end

  defp reconstruct_transaction([tx_type, outputs_rlp, nonce_rlp]) do
    with {:ok, 3} <- parse_uint256(tx_type),
         {:ok, outputs} <- parse_outputs(outputs_rlp),
         {:ok, nonce} <- reconstruct_nonce(nonce_rlp) do
      {:ok, %{tx_type: 3, outputs: outputs, nonce: nonce}}
    end
  end

  defp reconstruct_nonce(nonce) when is_binary(nonce) and byte_size(nonce) == 32, do: {:ok, nonce}
  defp reconstruct_nonce(_), do: {:error, :malformed_nonce}

  defp validate_metadata(metadata) when is_binary(metadata) and byte_size(metadata) == 32, do: {:ok, metadata}
  defp validate_metadata(_), do: {:error, :malformed_metadata}

  defp parse_inputs(inputs_rlp) do
    with true <- Enum.count(inputs_rlp) <= 4 || {:error, :too_many_inputs},
         # NOTE: workaround for https://github.com/omgnetwork/ex_plasma/issues/19.
         #       remove, when this is blocked on `ex_plasma` end
         true <- Enum.all?(inputs_rlp, &(&1 != <<0::256>>)) || {:error, :malformed_inputs},
         do: {:ok, Enum.map(inputs_rlp, &parse_input!/1)}
  rescue
    _ -> {:error, :malformed_inputs}
  end

  defp parse_input!(encoded) do
    {:ok, result} = decode_position(encoded)

    result
  end

  defp decode_position(encoded) when is_number(encoded) and encoded <= 0, do: {:error, :encoded_utxo_position_too_low}
  defp decode_position(encoded) when is_integer(encoded) and encoded > 0, do: do_decode_position(encoded)
  defp decode_position(encoded) when is_binary(encoded) and byte_size(encoded) == 32, do: do_decode_position(encoded)

  defp do_decode_position(encoded) do
    ExPlasma.Utxo.new(encoded)
  end

  defp parse_outputs(outputs_rlp) do
    outputs = Enum.map(outputs_rlp, &parse_output!/1)

    with true <- Enum.count(outputs) <= 4 || {:error, :too_many_outputs},
         nil <- Enum.find(outputs, &match?({:error, _}, &1)),
         do: {:ok, outputs}
  rescue
    _ -> {:error, :malformed_outputs}
  end

  defp parse_output!(rlp_data) do
    {:ok, result} = ExPlasma.Utxo.new(rlp_data)

    result
  end

  defp parse_uint256(<<0>> <> _binary), do: {:error, :leading_zeros_in_encoded_uint}
  defp parse_uint256(binary) when byte_size(binary) <= 32, do: {:ok, :binary.decode_unsigned(binary, :big)}
  defp parse_uint256(binary) when byte_size(binary) > 32, do: {:error, :encoded_uint_too_big}
  defp parse_uint256(_), do: {:error, :malformed_uint256}

  defp try_submit_tx(tx, timeout) do
    {:ok, {blknum, txindex}} =
      Sync.repeat_until_success(fn -> do_submit_tx(tx) end, timeout, "Failed to submit transaction")

    {:ok, blknum, txindex}
  end

  defp do_submit_tx(tx) do
    Metrics.run_with_metrics(
      fn ->
        submit_request(tx)
      end,
      "Childchain.submit"
    )
  end

  defp submit_request(tx) do
    {:ok, response} =
      tx
      |> Transaction.encode()
      |> do_submit_tx_rpc()

    response
    |> Map.fetch!(:body)
    |> Jason.decode!()
    |> Map.fetch!("data")
    |> case do
      %{"blknum" => blknum, "tx_index" => tx_index} ->
        _ = Logger.debug("[Transaction submitted successfully {#{inspect(blknum)}, #{inspect(tx_index)}}")
        {:ok, {blknum, tx_index}}

      %{"code" => reason} ->
        _ =
          Logger.warn("Transaction submission has failed, reason: #{inspect(reason)}, tx inputs: #{inspect(tx.inputs)}")

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
