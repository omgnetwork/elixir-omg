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

defmodule OMG.Fees do
  @moduledoc """
  Transaction's fee validation functions.
  """

  alias OMG.Crypto
  alias OMG.MergeTransactionValidator
  alias OMG.State.Transaction
  alias OMG.Utxo

  require Utxo

  use OMG.Utils.LoggerExt

  @typedoc "A map of token addresses to a single fee spec"
  @type fee_t() :: %{Crypto.address_t() => fee_spec_t()}
  @typedoc """
  A map of transaction types to fees
  where fees is itself a map of token to fee spec
  """
  @type full_fee_t() :: %{non_neg_integer() => fee_t()}
  @type optional_fee_t() :: merged_fee_t() | :ignore_fees | :no_fees_required
  @typedoc "A map representing a single fee"
  @type fee_spec_t() :: %{
          amount: pos_integer(),
          subunit_to_unit: pos_integer(),
          pegged_amount: pos_integer(),
          pegged_currency: String.t(),
          pegged_subunit_to_unit: pos_integer(),
          updated_at: DateTime.t()
        }

  @typedoc """
  A map of currency to amounts used internally where amounts is a list of supported fee amounts.
  """
  @type typed_merged_fee_t() :: %{non_neg_integer() => merged_fee_t()}
  @type merged_fee_t() :: %{Crypto.address_t() => list(pos_integer())}

  @doc ~S"""
  Checks whether the surplus of tokens sent in a transaction (inputs - outputs) covers the fees
  depending on the fee model.

  ## Examples

      iex> Fees.check_if_covered(%{"eth" => 1, "omg" => 0}, %{"eth" => [1], "omg" => [3]})
      :ok
      iex> Fees.check_if_covered(%{"eth" => 1, "omg" => 0}, %{"eth" => [2, 1], "omg" => [1, 3]})
      :ok
      iex> Fees.check_if_covered(%{"eth" => 1}, %{"eth" => [2]})
      {:error, :fees_not_covered}
      iex> Fees.check_if_covered(%{"eth" => 2}, %{"eth" => [3, 1]})
      {:error, :fees_not_covered}
      iex> Fees.check_if_covered(%{"eth" => 1, "omg" => 1}, %{"eth" => [1]})
      {:error, :multiple_potential_currency_fees}
      iex> Fees.check_if_covered(%{"eth" => 2}, %{"eth" => [1]})
      {:error, :overpaying_fees}
      iex> Fees.check_if_covered(%{"eth" => 2}, %{"eth" => [1, 3]})
      {:error, :overpaying_fees}
      iex> Fees.check_if_covered(%{"eth" => 1}, :no_fees_required)
      {:error, :overpaying_fees}
      iex> Fees.check_if_covered(%{"eth" => 1}, :ignore_fees)
      :ok

  """
  @spec check_if_covered(implicit_paid_fee_by_currency :: map(), accepted_fees :: optional_fee_t()) ::
          :ok | {:error, :fees_not_covered} | {:error, :overpaying_fees} | {:error, :multiple_potential_currency_fees}
  # If :ignore_fees is given, we don't require any surplus of tokens. If surplus exists, it will be collected.
  def check_if_covered(_, :ignore_fees), do: :ok
  def check_if_covered(_, %{}), do: :ok

  # Otherwise we remove all non positive tokens from the map and process it
  def check_if_covered(implicit_paid_fee_by_currency, accepted_fees) do
    implicit_paid_fee_by_currency
    |> remove_zero_fees()
    |> check_positive_amounts(accepted_fees)
  end

  @doc ~S"""
  Returns the fees to pay for a particular transaction,
  and under particular fee specs listed in `fee_map`.

  ## Examples
  iex> OMG.Fees.for_transaction(
  ...> %OMG.State.Transaction.Recovered{
  ...>   signed_tx: %OMG.State.Transaction.Signed{raw_tx: OMG.State.Transaction.Payment.new([], [], <<0::256>>)}
  ...> },
  ...> %{
  ...>   1 => %{
  ...>     "eth" => [1],
  ...>     "omg" => [3]
  ...>   },
  ...>   2 => %{
  ...>     "eth" => [4],
  ...>     "omg" => [5]
  ...>   }
  ...> }
  ...> )
  %{
    "eth" => [1],
    "omg" => [3]
  }
  """
  @spec for_transaction(Transaction.Recovered.t(), merged_fee_t()) :: optional_fee_t()
  def for_transaction(transaction, fee_map) do
    case MergeTransactionValidator.is_merge_transaction?(transaction) do
      true -> :no_fees_required
      false -> get_fee_for_type(transaction, fee_map)
    end
  end

  # With :no_fees_required, we ensure that no surplus of token is given
  # meaning that input amount == output amount. This is used for merge transactions.
  defp check_positive_amounts([], :no_fees_required), do: :ok
  defp check_positive_amounts(_, :no_fees_required), do: {:error, :overpaying_fees}

  # When accepting fees, we ensure that only one fee token is given
  defp check_positive_amounts([], _), do: {:error, :fees_not_covered}

  # When accepting fees, we ensure that the paid amount matches exactly the required amount and that
  # the given surplus token is accepted as a fee token
  defp check_positive_amounts([{currency, paid_fee}], accepted_fees) do
    case Map.get(accepted_fees, currency) do
      nil ->
        {:error, :fees_not_covered}

      amounts ->
        check_if_exact_match(amounts, paid_fee)
    end
  end

  defp check_positive_amounts(_, _), do: {:error, :multiple_potential_currency_fees}

  defp remove_zero_fees(implicit_paid_fee_by_currency) do
    Enum.filter(implicit_paid_fee_by_currency, fn {_currency, paid_fee} ->
      paid_fee > 0
    end)
  end

  defp check_if_exact_match([current_amount | _] = amounts, paid_fee) do
    cond do
      paid_fee in amounts ->
        :ok

      current_amount > paid_fee ->
        {:error, :fees_not_covered}

      current_amount < paid_fee ->
        {:error, :overpaying_fees}
    end
  end

  defp get_fee_for_type(%Transaction.Recovered{signed_tx: %Transaction.Signed{raw_tx: %{tx_type: type}}}, fee_map) do
    case type do
      nil -> %{}
      type -> Map.get(fee_map, type, %{})
    end
  end

  defp get_fee_for_type(_, _fee_map), do: %{}
end
