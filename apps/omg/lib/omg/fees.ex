# Copyright 2019 OmiseGO Pte Ltd
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

  alias OMG.MergeTransactionValidator
  alias OMG.State.Transaction
  alias OMG.Utxo

  require Utxo

  use OMG.Utils.LoggerExt

  @type fee_t() :: %{Transaction.Payment.currency() => fee_spec_t()} | :no_fees_required
  @type fee_spec_t() :: %{
          amount: non_neg_integer,
          pegged_amount: non_neg_integer,
          pegged_currency: String.t(),
          pegged_subunit_to_unit: non_neg_integer,
          updated_at: DateTime.t()
        }

  @doc ~S"""
  Checks whether the transaction's inputs cover the fees.

  ## Examples

      iex> Fees.covered?(%{"eth" => 2}, %{"eth" => %{amount: 1}, "omg" => %{amount: 3}})
      true

  """
  @spec covered?(implicit_paid_fee_by_currency :: map(), fees :: fee_t()) :: boolean()
  def covered?(_, :no_fees_required), do: true

  def covered?(implicit_paid_fee_by_currency, fees) do
    for {input_currency, implicit_paid_fee} <- implicit_paid_fee_by_currency do
      case Map.get(fees, input_currency) do
        nil -> false
        %{amount: amount} -> amount <= implicit_paid_fee
      end
    end
    |> Enum.any?()
  end

  @doc ~S"""
  Returns the fees to pay for a particular transaction,
  and under particular fee specs listed in `fee_map`.

  ## Examples

      iex> OMG.Fees.for_transaction(%OMG.State.Transaction.Recovered{},
      ...> %{
      ...>  "eth" => %{
      ...>    amount: 1,
      ...>    pegged_amount: 4,
      ...>    pegged_currency: "USD",
      ...>    pegged_subunit_to_unit: 100,
      ...>    updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      ...>  },
      ...>  "omg" => %{
      ...>    amount: 3,
      ...>    pegged_amount: 4,
      ...>    pegged_currency: "USD",
      ...>    pegged_subunit_to_unit: 100,
      ...>    updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      ...>  }
      ...> }
      ...>)
      %{
        "eth" => %{
          amount: 1,
          pegged_amount: 4,
          pegged_currency: "USD",
          pegged_subunit_to_unit: 100,
          updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
        },
        "omg" => %{
          amount: 3,
          pegged_amount: 4,
          pegged_currency: "USD",
          pegged_subunit_to_unit: 100,
          updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
        }
      }

  """
  @spec for_transaction(Transaction.Recovered.t(), fee_t()) :: fee_t()
  def for_transaction(transaction, fee_map) do
    case MergeTransactionValidator.is_merge_transaction?(transaction) do
      true -> :no_fees_required
      false -> fee_map
    end
  end

  @doc ~S"""
  Returns a filtered map of fees given a list of desired currencies.
  Fees will not be filtered if an empty list of currencies is given.

  ## Examples

      iex> OMG.Fees.filter_fees(
      ...> %{
      ...>  "eth" => %{
      ...>    amount: 1,
      ...>    pegged_amount: 4,
      ...>    pegged_currency: "USD",
      ...>    pegged_subunit_to_unit: 100,
      ...>    updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      ...>  },
      ...>  "omg" => %{
      ...>    amount: 3,
      ...>    pegged_amount: 4,
      ...>    pegged_currency: "USD",
      ...>    pegged_subunit_to_unit: 100,
      ...>    updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      ...>  }
      ...> },
      ...> ["eth"]
      ...> )
      {:ok,
        %{
          "eth" =>
          %{
            amount: 1,
            pegged_amount: 4,
            pegged_currency: "USD",
            pegged_subunit_to_unit: 100,
            updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
          }
        }
      }

  """
  @spec filter_fees(fee_t(), list(String.t())) :: {:ok, fee_t()} | {:error, :currency_fee_not_supported}
  # empty list = no filter
  def filter_fees(fees, []), do: {:ok, fees}

  def filter_fees(fees, desired_currencies) do
    Enum.reduce_while(desired_currencies, {:ok, %{}}, fn (currency, {:ok, filtered_fees}) ->
      case Map.fetch(fees, currency) do
        :error -> {:halt, {:error, :currency_fee_not_supported}}
        {:ok, fee} -> {:cont, {:ok, Map.put(filtered_fees, currency, fee)}}
      end
    end)
  end

  @doc ~S"""
  Formats the given fees for an api response.

  ## Examples

      iex> OMG.Fees.to_api_format(
      ...> %{
      ...>  "eth" => %{
      ...>    amount: 1,
      ...>    pegged_amount: 4,
      ...>    pegged_currency: "USD",
      ...>    pegged_subunit_to_unit: 100,
      ...>    updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      ...>  },
      ...>  "omg" => %{
      ...>    amount: 3,
      ...>    pegged_amount: 4,
      ...>    pegged_currency: "USD",
      ...>    pegged_subunit_to_unit: 100,
      ...>    updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      ...>  }
      ...> })
      [
        %{
          currency: "eth",
          amount: 1,
          pegged_amount: 4,
          pegged_currency: {:skip_hex_encode, "USD"},
          pegged_subunit_to_unit: 100,
          updated_at: {:skip_hex_encode, DateTime.from_iso8601("2019-01-01T10:10:00+00:00")}
        },
        %{
          currency: "omg",
          amount: 3,
          pegged_amount: 4,
          pegged_currency: {:skip_hex_encode, "USD"},
          pegged_subunit_to_unit: 100,
          updated_at: {:skip_hex_encode, DateTime.from_iso8601("2019-01-01T10:10:00+00:00")}
        },
      ]

  """
  @spec to_api_format(fee_t()) :: list(map())
  def to_api_format(fees) do
    Enum.map(fees, fn {currency,
                       %{
                         amount: amount,
                         pegged_currency: pegged_currency,
                         pegged_amount: pegged_amount,
                         pegged_subunit_to_unit: pegged_subunit_to_unit,
                         updated_at: updated_at
                       }} ->
      %{
        currency: currency,
        amount: amount,
        pegged_currency: {:skip_hex_encode, pegged_currency},
        pegged_amount: pegged_amount,
        pegged_subunit_to_unit: pegged_subunit_to_unit,
        updated_at: {:skip_hex_encode, updated_at}
      }
    end)
  end
end
