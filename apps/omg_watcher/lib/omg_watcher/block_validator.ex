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

defmodule OMG.Watcher.BlockValidator do
  @moduledoc """
  Operations related to block validation.
  """

  alias OMG.Block
  alias OMG.Merkle
  alias OMG.Output
  alias OMG.State.Transaction
  alias OMG.Utxo

  @transaction_upper_limit 2 |> :math.pow(16) |> Kernel.trunc()
  @fee_claimer_address OMG.Configuration.fee_claimer_address()

  @doc """
  Executes stateless validation of a submitted block:
  - Verifies that the number of transactions falls within the accepted range.
  - Verifies that transactions are correctly formed.
  - Verifies that there are no duplicate inputs at the block level.
  - Verifies that given Merkle root matches reconstructed Merkle root.
  - Verifies that fee transactions are correctly placed, calculated and unique per currency.
  """
  @spec stateless_validate(Block.t()) :: {:ok, boolean()} | {:error, atom()}
  def stateless_validate(submitted_block) do
    with :ok <- number_of_transactions_within_limit(submitted_block.transactions),
         {:ok, recovered_transactions} <- verify_transactions(submitted_block.transactions),
         {:ok, _fee_transactions} <- verify_fee_transactions(recovered_transactions),
         {:ok, _inputs} <- verify_no_duplicate_inputs(recovered_transactions),
         {:ok, _block} <- verify_merkle_root(submitted_block, recovered_transactions) do
      {:ok, true}
    end
  end

  @spec verify_merkle_root(Block.t(), list(Transaction.Recovered.t())) ::
          {:ok, Block.t()} | {:error, :mismatched_merkle_root}
  defp verify_merkle_root(block, transactions) do
    reconstructed_merkle_hash =
      transactions
      |> Enum.map(&Transaction.raw_txbytes/1)
      |> Merkle.hash()

    case block.hash do
      ^reconstructed_merkle_hash -> {:ok, block}
      _ -> {:error, :invalid_merkle_root}
    end
  end

  @spec verify_transactions(transactions :: list(Transaction.Signed.tx_bytes())) ::
          {:ok, list(Transaction.Recovered.t())}
          | {:error, Transaction.Recovered.recover_tx_error()}
  defp verify_transactions(transactions) do
    transactions
    |> Enum.reverse()
    |> Enum.reduce_while({:ok, []}, fn tx, {:ok, already_recovered} ->
      case Transaction.Recovered.recover_from(tx) do
        {:ok, recovered} ->
          {:cont, {:ok, [recovered | already_recovered]}}

        error ->
          {:halt, error}
      end
    end)
  end

  @spec number_of_transactions_within_limit([Transaction.Signed.tx_bytes()]) ::
          :ok | {:error, atom()}
  defp number_of_transactions_within_limit(transactions) do
    case length(transactions) do
      # A block with a merge transaction only would have no fee transaction.
      0 ->
        {:error, :empty_block}

      n when n > @transaction_upper_limit ->
        {:error, :transactions_exceed_block_limit}

      _ ->
        :ok
    end
  end

  @spec verify_no_duplicate_inputs([Transaction.Recovered.t()]) :: {:ok, map()}
  defp(verify_no_duplicate_inputs(transactions)) do
    Enum.reduce_while(transactions, {:ok, %{}}, fn tx, {:ok, input_set} ->
      tx
      |> Map.get(:signed_tx)
      |> Map.get(:raw_tx)
      |> Map.get(:inputs, [])
      # Setting an empty array as default because fee transactions will not have an `input` key.
      |> scan_for_duplicates({:cont, {:ok, input_set}})
    end)
  end

  # Nested reducer executing duplicate verification logic for `verify_no_duplicate_inputs/1`
  @spec scan_for_duplicates(Transaction.Recovered.t(), {:cont, {:ok, map()}}) :: {:cont, {:ok, map()}}
  defp scan_for_duplicates(tx_input_set, {:cont, {:ok, input_set}}) do
    Enum.reduce_while(tx_input_set, {:cont, {:ok, input_set}}, fn input, {:cont, {:ok, input_set}} ->
      input_position = Utxo.Position.encode(input)

      case Map.has_key?(input_set, input_position) do
        true -> {:halt, {:halt, {:error, :block_duplicate_inputs}}}
        false -> {:cont, {:cont, {:ok, Map.put(input_set, input_position, true)}}}
      end
    end)
  end

  @spec verify_fee_transactions([Transaction.Recovered.t()]) :: {:ok, [Transaction.Recovered.t()]} | {:error, atom()}
  defp verify_fee_transactions(transactions) do
    {identified_fee_transactions, expected_fees_by_ccy} = scan_for_block_fee_information(transactions)

    with :ok <- expected_number(identified_fee_transactions, expected_fees_by_ccy),
         :ok <- expected_index(transactions, identified_fee_transactions),
         :ok <- expected_amounts(identified_fee_transactions, expected_fees_by_ccy) do
      {:ok, identified_fee_transactions}
    end
  end

  @spec expected_number([Transaction.Recovered.t()], %{binary() => integer()}) :: :ok | {:error, atom()}
  defp expected_number(identified_fee_transactions, expected_fees_by_ccy) do
    expected_number_of_fee_transactions = expected_fees_by_ccy |> Map.keys() |> length

    case length(identified_fee_transactions) do
      ^expected_number_of_fee_transactions ->
        :ok

      n when n < expected_number_of_fee_transactions ->
        {:error, :missing_fee_transactions_in_block}

      n when n > expected_number_of_fee_transactions ->
        {:error, :excess_fee_transactions_in_block}
    end
  end

  @spec expected_index([Transaction.Recovered.t()], [Transaction.Recovered.t()]) :: :ok | {:error, atom()}
  defp expected_index(transactions, identified_fee_transactions) do
    tail =
      Enum.slice(
        transactions,
        -length(identified_fee_transactions),
        length(identified_fee_transactions)
      )

    case Enum.reverse(identified_fee_transactions) do
      ^tail -> :ok
      _ -> {:error, :unexpected_transaction_type_at_fee_index}
    end
  end

  @spec expected_amounts([Transaction.Recovered.t()], %{binary() => integer()}) :: :ok | {:error, atom()}
  defp expected_amounts(identified_fee_transactions, expected_fees_by_ccy) do
    Enum.reduce_while(identified_fee_transactions, :ok, fn fee_transaction, _acc ->
      %Output{currency: currency, amount: amount} = get_fee_output(fee_transaction)

      case expected_fees_by_ccy[currency] do
        ^amount -> {:cont, :ok}
        _ -> {:halt, {:error, :unexpected_fee_transaction_amount}}
      end
    end)
  end

  @spec scan_for_block_fee_information([Transaction.Recovered.t()]) ::
          {[Transaction.Recovered.t()], %{binary() => integer()}}
  def scan_for_block_fee_information(transactions) do
    Enum.reduce(transactions, {[], %{}}, fn transaction, acc -> extract_info_for_block_fee_scan(transaction, acc) end)
  end

  # Callback function executing logic in reducer for `scan_block_for_fee_information/1`
  defp extract_info_for_block_fee_scan(transaction, {fee_transactions, expected_fees_by_ccy} = acc) do
    case is_fee(transaction) do
      true ->
        {[transaction | fee_transactions], expected_fees_by_ccy}

      false ->
        case find_fee_output(transaction) do
          nil ->
            acc

          %Output{currency: currency, amount: o_amount} ->
            {
              fee_transactions,
              Map.update(expected_fees_by_ccy, currency, o_amount, fn acc_ccy_amount -> acc_ccy_amount + o_amount end)
            }
        end
    end
  end

  defp is_fee(%Transaction.Recovered{signed_tx: %Transaction.Signed{raw_tx: %Transaction.Fee{}}}),
    do: true

  defp is_fee(_), do: false

  defp get_fee_output(fee_transaction) do
    case fee_transaction do
      %Transaction.Recovered{
        signed_tx: %Transaction.Signed{raw_tx: %Transaction.Fee{outputs: [fee_output]}}
      } ->
        fee_output

      _ ->
        {:error, :malformed_fee_transaction}
    end
  end

  @spec find_fee_output(Transaction.Recovered.t()) :: Output.t() | nil
  defp find_fee_output(transaction) do
    transaction
    |> Map.get(:signed_tx)
    |> Map.get(:raw_tx)
    |> Map.get(:outputs)
    |> Enum.find(fn output -> output.owner == @fee_claimer_address end)
  end
end
