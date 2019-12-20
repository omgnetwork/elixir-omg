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
  alias OMG.WireFormatTypes

  require Utxo

  use OMG.Utils.LoggerExt

  @type fee_t() :: %{Transaction.Payment.currency() => fee_spec_t()}
  @type full_fee_t() :: %{binary() => fee_t()}
  @type optional_fee_t() :: fee_t() | :no_fees_required
  @type fee_spec_t() :: %{
          amount: non_neg_integer,
          subunit_to_unit: non_neg_integer,
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
  @spec covered?(implicit_paid_fee_by_currency :: map(), fees :: optional_fee_t()) :: boolean()
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

      iex> OMG.Fees.for_transaction(%OMG.State.Transaction.Recovered{signed_tx: %OMG.State.Transaction.Signed{raw_tx: OMG.State.Transaction.Payment.new([], [], <<0::256>>)}},
      ...> %{
      ...>  1 => %{
      ...>    "eth" => %{
      ...>      amount: 1,
      ...>      subunit_to_unit: 1000000000000000000,
      ...>      pegged_amount: 4,
      ...>      pegged_currency: "USD",
      ...>      pegged_subunit_to_unit: 100,
      ...>      updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      ...>    },
      ...>    "omg" => %{
      ...>      amount: 3,
      ...>      subunit_to_unit: 1000000000000000000,
      ...>      pegged_amount: 4,
      ...>      pegged_currency: "USD",
      ...>      pegged_subunit_to_unit: 100,
      ...>      updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      ...>    }
      ...>  }
      ...> }
      ...>)
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
    case WireFormatTypes.module_tx_types()[raw_tx.__struct__] do
      nil -> %{}
      type -> Map.get(fee_map, type, %{})
    end
  end

  defp get_fee_for_type(_, _fee_map), do: %{}

  @doc ~S"""
  Returns a filtered map of fees given a list of transaction types and currencies.
  Passing a nil value or an empty array skip the filtering.

  ## Examples

      iex> OMG.Fees.filter_fees(
      ...>   %{
      ...>     1 => %{
      ...>       "eth" => %{
      ...>         amount: 1,
      ...>         subunit_to_unit: 1_000_000_000_000_000_000,
      ...>         pegged_amount: 4,
      ...>         pegged_currency: "USD",
      ...>         pegged_subunit_to_unit: 100,
      ...>         updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      ...>       },
      ...>       "omg" => %{
      ...>         amount: 3,
      ...>         subunit_to_unit: 1_000_000_000_000_000_000,
      ...>         pegged_amount: 4,
      ...>         pegged_currency: "USD",
      ...>         pegged_subunit_to_unit: 100,
      ...>         updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      ...>       }
      ...>     },
      ...>     2 => %{
      ...>       "omg" => %{
      ...>         amount: 3,
      ...>         subunit_to_unit: 1_000_000_000_000_000_000,
      ...>         pegged_amount: 4,
      ...>         pegged_currency: "USD",
      ...>         pegged_subunit_to_unit: 100,
      ...>         updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      ...>       }
      ...>     },
      ...>     3 => %{
      ...>       "omg" => %{
      ...>         amount: 3,
      ...>         subunit_to_unit: 1_000_000_000_000_000_000,
      ...>         pegged_amount: 4,
      ...>         pegged_currency: "USD",
      ...>         pegged_subunit_to_unit: 100,
      ...>         updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      ...>       }
      ...>     }
      ...>   },
      ...>   [1,2],
      ...>   ["eth"]
      ...> )
      {:ok,
        %{
          1 => %{
            "eth" => %{
              amount: 1,
              subunit_to_unit: 1_000_000_000_000_000_000,
              pegged_amount: 4,
              pegged_currency: "USD",
              pegged_subunit_to_unit: 100,
              updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
            }
          },
          2 => %{}
        }
      }

  """
  @spec filter_fees(full_fee_t(), list(pos_integer()), list(String.t()) | nil) ::
          {:ok, full_fee_t()} | {:error, :currency_fee_not_supported}
  # empty list = no filter
  def filter_fees(fees, []), do: {:ok, fees}
  def filter_fees(fees, nil), do: {:ok, fees}

  def filter_fees(fees, tx_types, currencies) do
    with {:ok, fees} <- filter_tx_type(fees, tx_types) do
      filtter_currency(fees, currencies)
    end
  end

  defp filter_tx_type(fees, []), do: {:ok, fees}
  defp filter_tx_type(fees, nil), do: {:ok, fees}

  defp filter_tx_type(fees, tx_types) do
    with :ok <- validate_tx_types(tx_types, fees), do: {:ok, Map.take(fees, tx_types)}
  end

  defp validate_tx_types(tx_types, fees) do
    tx_types
    |> Enum.all?(&Map.has_key?(fees, &1))
    |> case do
      true -> :ok
      false -> {:error, :tx_type_not_supported}
    end
  end

  defp filtter_currency(fees, []), do: {:ok, fees}
  defp filtter_currency(fees, nil), do: {:ok, fees}

  defp filtter_currency(fees, currencies) do
    with :ok <- validate_currencies(currencies, fees) do
      {:ok, do_filter_currencies(currencies, fees)}
    end
  end

  defp validate_currencies(currencies, fees) do
    currencies
    |> Enum.all?(fn currency -> Enum.any?(fees, &Map.has_key?(elem(&1, 1), currency)) end)
    |> case do
      true -> :ok
      false -> {:error, :currency_fee_not_supported}
    end
  end

  defp do_filter_currencies(currencies, fees) do
    fees
    |> Enum.map(&{elem(&1, 0), Map.take(elem(&1, 1), currencies)})
    |> Enum.into(%{})
  end
end
