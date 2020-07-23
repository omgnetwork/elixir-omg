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

defmodule OMG.DB.Monitor.MeasurementCalculation do
  @moduledoc """
  Calculates measurements for OMG.DB.
  """
  alias OMG.Eth
  alias OMG.Utxo

  @doc """
  Returns the sum of unspent amounts per currency.

  NOTE: we're counting only outputs that define a currency and amount, so that this remains
  a balance-counting metric. For anything, where the balance isn't well defined,
  careful rethinking would be required
  """
  @spec balances_by_currency([Utxo.t()]) :: %{required(Eth.address()) => non_neg_integer()}
  def balances_by_currency(utxos) do
    utxos
    |> Enum.map(fn {_, %OMG.Utxo{output: output}} -> output end)
    |> Enum.map(&{Map.get(&1, :currency), Map.get(&1, :amount, 0)})
    |> Enum.filter(fn {currency, _amount} -> currency end)
    |> Enum.reduce(%{}, fn {currency, amount}, acc ->
      Map.update(acc, currency, amount, &(&1 + amount))
    end)
  end

  @doc """
  Returns the total number of unique addresses in posession of at least 1 unspent output.

  NOTE: we're counting only outputs that define an owner, so that this remains
  an owner-counting metric. For anything, where the owner isn't well defined,
  careful rethinking would be required
  """
  @spec total_unspent_addresses([Utxo.t()]) :: non_neg_integer()
  def total_unspent_addresses(utxos) do
    utxos
    |> Enum.map(fn {_utxopos, %Utxo{output: output}} -> output end)
    |> Enum.map(&Map.get(&1, :owner))
    |> Enum.filter(& &1)
    |> Enum.uniq()
    |> Enum.count()
  end

  @doc """
  Returns the total number of unspent outputs.
  """
  @spec total_unspent_outputs([Utxo.t()]) :: non_neg_integer()
  def total_unspent_outputs(utxos) do
    utxos
    |> Enum.map(fn {_utxopos, %Utxo{output: output}} -> output end)
    |> Enum.filter(fn output -> Map.has_key?(output, :amount) end)
    |> Enum.count()
  end
end
