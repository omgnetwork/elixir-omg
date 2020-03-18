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
defmodule Itest.Fee do
  @moduledoc """
  Functions to pull fees
  """

  alias Itest.Client
  alias Itest.Transactions.PaymentType

  @payment_tx_type PaymentType.simple_payment_transaction() |> Binary.to_integer() |> Integer.to_string()

  @doc """
  get all supported fees for payment transactions
  """
  def get_fees() do
    {:ok, %{@payment_tx_type => fees}} = Client.get_fees()
    fees
  end

  @doc """
  get the fee for a specific currency
  """
  def get_for_currency(currency) do
    fees = get_fees()
    Enum.find(fees, &(&1["currency"] == currency))
  end
end
