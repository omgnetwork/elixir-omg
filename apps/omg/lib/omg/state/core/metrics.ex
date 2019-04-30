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

defmodule OMG.State.Core.Metrics do
  @moduledoc """
  Counting business metrics sent to appsignal
  """

  alias OMG.Eth.Encoding
  alias OMG.State.Core

  def calculate(%Core{utxos: utxos}) do
    [
      {"unique_users", unique_users(utxos)}
      | balance(utxos)
        |> Enum.map(fn {currency, amount} -> {"balance_" <> Encoding.to_hex(currency), amount} end)
    ]
  end

  defp unique_users(utxos) do
    utxos
    |> Enum.map(fn {_, %OMG.Utxo{owner: owner}} -> owner end)
    |> Enum.uniq()
    |> Enum.count()
  end

  defp balance(utxos) do
    Enum.reduce(utxos, %{}, fn {_, %{currency: currency, amount: amount}}, acc ->
      Map.update(acc, currency, amount, &(&1 + amount))
    end)
  end
end
