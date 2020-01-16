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
  @type optional_fee_t() :: fee_t() | :no_fees_required
  @typedoc "A map representing a single fee"
  @type fee_spec_t() :: %{
          amount: non_neg_integer(),
          subunit_to_unit: pos_integer(),
          pegged_amount: pos_integer(),
          pegged_currency: String.t(),
          pegged_subunit_to_unit: pos_integer(),
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
