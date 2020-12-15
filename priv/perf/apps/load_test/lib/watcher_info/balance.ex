# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule LoadTest.WatcherInfo.Balance do
  @moduledoc """
  Functions related to balances on the childchain
  """
  require Logger

  alias ExPlasma.Encoding
  alias LoadTest.Ethereum.Account
  alias LoadTest.Service.Sync
  alias LoadTest.WatcherInfo.Client

  @poll_timeout 60_000

  @spec fetch_balance(Account.addr_t(), non_neg_integer(), Account.addr_t()) :: non_neg_integer() | :error | nil | map()
  def fetch_balance(address, amount, currency \\ <<0::160>>) do
    {:ok, result} =
      Sync.repeat_until_success(
        fn ->
          do_fetch_balance(Encoding.to_hex(address), amount, Encoding.to_hex(currency))
        end,
        @poll_timeout,
        "Failed to fetch childchain balance"
      )

    result
  end

  defp do_fetch_balance(address, amount, currency) do
    response =
      case Client.get_balances(address) do
        {:ok, decoded_response} ->
          Enum.find(decoded_response["data"], fn data -> data["currency"] == currency end)

        result ->
          Logger.error("Failed to fetch balance from childchain #{inspect(result)}")

          :error
      end

    case response do
      # empty response is considered no account balance!
      nil when amount == 0 ->
        {:ok, nil}

      %{"amount" => ^amount} = balance ->
        {:ok, balance}

      response ->
        {:error, response}
    end
  end
end
