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

defmodule OMG.WatcherRPC.Web.Validator.MergeConstraints do
  @moduledoc """
  Validates `/transaction.merge` parameters
  """

  import OMG.Utils.HttpRPC.Validator.Base

  @doc """
  Parses and validates request body
  """
  @spec parse(map()) :: {:ok, map()} | Base.validation_error_t()
  def parse(%{"address" => _address, "currency" => _currency} = params) do
    with {:ok, address} <- expect(params, "address", :address),
        {:ok, currency} <- expect(params, "currency", :currency) do
      {:ok,
      %{
        address: address,
        currency: currency
      }}
    end
  end

  def parse(%{"utxos" => _utxos} = params) do
    with {:ok, _utxos} <- expect(params, "utxos", [:list, min_length: 2, max_length: 4]),
        {:ok, validated_utxos} <- validate_utxos(params["utxos"]) do
      {:ok,
      %{
        utxos: Enum.reverse(validated_utxos)
      }}
    end
  end

  def parse(%{"utxo_positions" => _utxo_positions} = params) do
    with {:ok, utxo_positions} <- expect(params, "utxo_positions", [list: &to_utxo_pos/1, min_length: 2, max_length: 4]) do
      {:ok,
      %{
        utxo_positions: utxo_positions
      }}
    end
  end

  def parse(_), do: {:error, :operation_bad_request}

  defp validate_utxos(utxos) do
    Enum.reduce_while(utxos, {:ok, []}, fn utxo, {:ok, acc} ->
      with {:ok, _blknum} <- expect(utxo, "blknum", :pos_integer),
        {:ok, _txindex} <- expect(utxo, "txindex", :pos_integer),
        {:ok, _oindex} <- expect(utxo, "oindex", :pos_integer),
        {:ok, _owner} <- expect(utxo, "owner", :address),
        {:ok, _currency} <- expect(utxo, "currency", :currency),
        {:ok, _amount} <- expect(utxo, "amount", :pos_integer) do
        {:cont, {:ok, [utxo | acc]}}
      else
        error -> {:halt, error}
      end
    end)
  end

  defp to_utxo_pos(utxo_pos_string) do
    expect(%{"utxo_pos" => utxo_pos_string}, "utxo_pos", :non_neg_integer)
  end
end
