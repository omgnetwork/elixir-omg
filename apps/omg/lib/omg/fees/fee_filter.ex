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

defmodule OMG.Fees.FeeFilter do
  @moduledoc """
  Filtering of fees.
  """

  alias OMG.Fees

  @doc ~S"""
  Returns a filtered map of fees given a list of transaction types and currencies.
  Passing a nil value or an empty array skip the filtering.

  ## Examples

      iex> OMG.Fees.FeeFilter.filter(
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
  @spec filter(Fees.full_fee_t(), list(non_neg_integer()), list(String.t()) | nil) ::
          {:ok, Fees.full_fee_t()} | {:error, :currency_fee_not_supported} | {:error, :tx_type_not_supported}
  # empty list = no filter
  def filter(fees, []), do: {:ok, fees}
  def filter(fees, nil), do: {:ok, fees}

  def filter(fees, tx_types, currencies) do
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
    |> Enum.map(fn {tx_type, fees_for_tx_type} ->
      {tx_type, Map.take(fees_for_tx_type, currencies)}
    end)
    |> Enum.into(%{})
  end
end
