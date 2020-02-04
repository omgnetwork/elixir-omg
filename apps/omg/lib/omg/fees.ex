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
  alias OMG.WireFormatTypes

  require Utxo

  use OMG.Utils.LoggerExt

  @typedoc "A map of token addresses to a single fee spec"
  @type fee_t() :: %{Crypto.address_t() => fee_spec_t()}
  @typedoc """
  A map of transaction types to fees
  where fees is itself a map of token to fee spec
  """
  @type full_fee_t() :: %{non_neg_integer() => fee_t()}
  @type optional_fee_t() :: fee_t() | :ignore_fees | :no_fees_required
  @typedoc "A map representing a single fee"
  @type fee_spec_t() :: %{
          amount: pos_integer(),
          subunit_to_unit: pos_integer(),
          pegged_amount: pos_integer(),
          pegged_currency: String.t(),
          pegged_subunit_to_unit: pos_integer(),
          updated_at: DateTime.t()
        }

  @doc ~S"""
  Checks whether the surplus of tokens sent in a transaction (inputs - outputs) covers the fees
  depending on the fee model.

  ## Examples

      iex> Fees.check_if_covered(%{"eth" => 1, "omg" => 0}, %{"eth" => %{amount: 1}, "omg" => %{amount: 3}})
      :ok
      iex> Fees.check_if_covered(%{"eth" => 1}, %{"eth" => %{amount: 2}})
      {:error, :fees_not_covered}
      iex> Fees.check_if_covered(%{"eth" => 1, "omg" => 1}, %{"eth" => %{amount: 1}})
      {:error, :multiple_potential_currency_fees}
      iex> Fees.check_if_covered(%{"eth" => 2}, %{"eth" => %{amount: 1}})
      {:error, :overpaying_fees}
      iex> Fees.check_if_covered(%{"eth" => 1}, :no_fees_required)
      {:error, :overpaying_fees}
      iex> Fees.check_if_covered(%{"eth" => 1}, :ignore_fees)
      :ok

  """
  @spec check_if_covered(implicit_paid_fee_by_currency :: map(), accepted_fees :: optional_fee_t()) ::
          :ok | {:error, :fees_not_covered} | {:error, :overpaying_fees} | {:error, :multiple_potential_currency_fees}
  # If :ignore_fees is given, we ignore any surplus of tokens
  def check_if_covered(_, :ignore_fees), do: :ok

  # Otherwise we remove all non positive tokens from the map and process it
  def check_if_covered(implicit_paid_fee_by_currency, accepted_fees) do
    implicit_paid_fee_by_currency
    |> remove_zero_fees()
    |> check_positive_amounts(accepted_fees)
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

      %{amount: amount} ->
        check_if_exact_match(amount, paid_fee)
    end
  end

  defp check_positive_amounts(_, _), do: {:error, :multiple_potential_currency_fees}

  defp remove_zero_fees(implicit_paid_fee_by_currency) do
    Enum.filter(implicit_paid_fee_by_currency, fn {_currency, paid_fee} ->
      paid_fee > 0
    end)
  end

  defp check_if_exact_match(amount, paid_fee) do
    cond do
      amount == paid_fee ->
        :ok

      amount > paid_fee ->
        {:error, :fees_not_covered}

      amount < paid_fee ->
        {:error, :overpaying_fees}
    end
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
  ...>     "eth" => %{
  ...>       amount: 1,
  ...>       subunit_to_unit: 1_000_000_000_000_000_000,
  ...>       pegged_amount: 4,
  ...>       pegged_currency: "USD",
  ...>       pegged_subunit_to_unit: 100,
  ...>       updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
  ...>     },
  ...>     "omg" => %{
  ...>       amount: 3,
  ...>       subunit_to_unit: 1_000_000_000_000_000_000,
  ...>       pegged_amount: 4,
  ...>       pegged_currency: "USD",
  ...>       pegged_subunit_to_unit: 100,
  ...>       updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
  ...>     }
  ...>   }
  ...> }
  ...> )
  %{
    "eth" => %{
      amount: 1,
      subunit_to_unit: 1000000000000000000,
      pegged_amount: 4,
      pegged_currency: "USD",
      pegged_subunit_to_unit: 100,
      updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
    },
    "omg" => %{
      amount: 3,
      subunit_to_unit: 1000000000000000000,
      pegged_amount: 4,
      pegged_currency: "USD",
      pegged_subunit_to_unit: 100,
      updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
    }
  }

  """
  @spec for_transaction(Transaction.Recovered.t(), full_fee_t()) :: optional_fee_t()
  def for_transaction(transaction, fee_map) do
    case MergeTransactionValidator.is_merge_transaction?(transaction) do
      true -> :no_fees_required
      false -> get_fee_for_type(transaction, fee_map)
    end
  end

  defp get_fee_for_type(%Transaction.Recovered{signed_tx: %Transaction.Signed{raw_tx: raw_tx}}, fee_map) do
    case WireFormatTypes.tx_type_for_transaction(raw_tx) do
      nil -> %{}
      type -> Map.get(fee_map, type, %{})
    end
  end

  defp get_fee_for_type(_, _fee_map), do: %{}
end
