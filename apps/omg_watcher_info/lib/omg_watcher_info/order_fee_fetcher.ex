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

defmodule OMG.WatcherInfo.OrderFeeFetcher do
  @moduledoc """
  Handle fetching and formatting of fees for an order
  """

  alias OMG.Crypto
  alias OMG.State.Transaction
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.WatcherInfo.HttpRPC.Client
  alias OMG.WatcherInfo.UtxoSelection
  alias OMG.WireFormatTypes

  # Note: Hardcoding the tx_type for now
  @tx_type WireFormatTypes.tx_type_for(:tx_payment_v1)
  @str_tx_type Integer.to_string(@tx_type)

  @type order_without_fee_amount_t() :: %{
          owner: Crypto.address_t(),
          payments: nonempty_list(UtxoSelection.payment_t()),
          fee: %{currency: Transaction.Payment.currency()},
          metadata: binary() | nil
        }

  @doc """
  Fetch the correct fee amount for the given fee currency from the childchain
  and adds it to the order map.
  """
  @spec add_fee_to_order(order_without_fee_amount_t()) :: {:ok, UtxoSelection.order_t()} | {:error, atom()}
  def add_fee_to_order(%{fee: %{currency: currency}} = order, url \\ nil) do
    child_chain_url = url || Application.get_env(:omg_watcher_info, :child_chain_url)
    encoded_currency = Encoding.to_hex(currency)
    params = %{"currencies" => [encoded_currency], "tx_types" => [@tx_type]}

    with {:ok, fees} <- Client.get_fees(params, child_chain_url),
         {:ok, amount} <- validate_child_chain_fees(fees, encoded_currency) do
      {:ok, Kernel.put_in(order, [:fee, :amount], amount)}
    else
      error ->
        error
    end
  end

  defp validate_child_chain_fees(fees, currency) do
    case fees do
      %{@str_tx_type => [%{"amount" => amount, "currency" => ^currency} | _]} ->
        {:ok, amount}

      _ ->
        {:error, :unexpected_fee}
    end
  end
end
