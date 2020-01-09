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

defmodule OMG.WatcherInfo.OrderFeeFetcher do
  @moduledoc """
  Handle fetching and foratting of fees for an order
  """

  alias OMG.WatcherInfo.HttpRPC.Client
  alias OMG.WireFormatTypes
  alias OMG.Utils.HttpRPC.Encoding

  # Note: Hardcoding the tx_type for now
  @tx_type WireFormatTypes.tx_type_for(:tx_payment_v1)
  @str_tx_type Integer.to_string(@tx_type)

  def add_fee_to_order(%{fee: %{currency: currency}} = order) do
    child_chain_url = Application.get_env(:omg_watcher, :child_chain_url)
    encoded_currency = Encoding.to_hex(currency)

    %{"currencies" => [encoded_currency], "tx_types" => [@tx_type]}
    |> Client.get_fees(child_chain_url)
    |> parse_response(encoded_currency)
    |> respond(order)
  end

  defp parse_response({:ok, fees}, currency) do
    with %{@str_tx_type => [%{"amount" => amount, "currency" => ^currency} | _]} <- fees do
      {:ok, amount}
    else
      _ -> {:error, :unexpected_fee}
    end
  end

  defp parse_response(error, _), do: error

  defp respond({:ok, amount}, %{fee: fee} = order) do
    {:ok, Map.put(order, :fee, Map.put(fee, :amount, amount))}
  end

  defp respond(error, _), do: error
end
