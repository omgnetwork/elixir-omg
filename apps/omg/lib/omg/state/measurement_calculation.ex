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
defmodule OMG.State.MeasurementCalculation do
  @moduledoc """
   Calculations based on OMG State that are sent to monitoring service.
  """
  alias OMG.Eth.Encoding
  alias OMG.State.Core

  # TODO: functions here reach uncleanly into the UtxoSet (not going through `OMG.State.UtxoSet`) - is this bad?

  def calculate(%Core{utxos: utxos}) do
    balance =
      Enum.map(
        balance(utxos),
        fn {currency, amount} ->
          {:balance, amount, "currency:#{Encoding.to_hex(currency)}"}
        end
      )

    unique_users = {:unique_users, unique_users(utxos)}
    List.flatten([unique_users, balance])
  end

  defp unique_users(utxos) do
    utxos
    |> Enum.map(fn {_, %OMG.Utxo{output: output}} -> output end)
    # NOTE: we're counting only outputs that define an owner, so that this remains an owner-counting metric.
    #       For anything, where the owner isn't well defined, careful rethinking would be required
    |> Enum.map(&Map.get(&1, :owner))
    |> Enum.filter(& &1)
    |> Enum.uniq()
    |> Enum.count()
  end

  defp balance(utxos) do
    utxos
    |> Enum.map(fn {_, %OMG.Utxo{output: output}} -> output end)
    # NOTE: we're counting only outputs that define a currency and amount, so that this remains a balance-counting
    #       metric. For anything, where the balance isn't well defined, careful rethinking would be required
    |> Enum.map(&{Map.get(&1, :currency), Map.get(&1, :amount, 0)})
    |> Enum.filter(fn {currency, _} -> currency end)
    |> Enum.reduce(%{}, fn {currency, amount}, acc ->
      Map.update(acc, currency, amount, &(&1 + amount))
    end)
  end
end
