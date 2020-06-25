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
defmodule Itest.Gas do
  @moduledoc """
  Functions to pull gas charges from the transaction hash
  """

  require Logger

  @doc """
    Nil for when exit queue hash is nil (because it's already added)
  """
  def get_gas_used(nil), do: 0

  def get_gas_used(receipt_hash) do
    result =
      {Ethereumex.HttpClient.eth_get_transaction_receipt(receipt_hash),
       Ethereumex.HttpClient.eth_get_transaction_by_hash(receipt_hash)}

    case result do
      {{:ok, %{"gasUsed" => gas_used}}, {:ok, %{"gasPrice" => gas_price}}} ->
        {gas_price_value, ""} = gas_price |> String.replace_prefix("0x", "") |> Integer.parse(16)
        {gas_used_value, ""} = gas_used |> String.replace_prefix("0x", "") |> Integer.parse(16)
        gas_price_value * gas_used_value

      {{:ok, nil}, {:ok, nil}} ->
        0
    end
  end

  def with_retries(func, total_time \\ 510, current_time \\ 0) do
    case func.() do
      {:ok, nil} ->
        Process.sleep(1_000)
        with_retries(func, total_time, current_time + 1)

      {:ok, _} = result ->
        result

      result ->
        if current_time < total_time do
          Process.sleep(1_000)
          with_retries(func, total_time, current_time + 1)
        else
          result
        end
    end
  end
end
