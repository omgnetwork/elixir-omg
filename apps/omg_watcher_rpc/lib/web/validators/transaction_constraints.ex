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

defmodule OMG.WatcherRPC.Web.Validator.TransactionConstraints do
  @moduledoc """
  Validates `/transaction.all` query parameters
  """

  import OMG.Utils.HttpRPC.Validator.Base

  @max_tx_types 16

  @doc """
  Validates possible query constraints, stops on first error.
  """
  @spec parse(%{binary() => any()}) :: {:ok, Keyword.t()} | {:error, any()}
  def parse(params) do
    constraints = [
      {"address", [:address, :optional], :address},
      {"blknum", [:pos_integer, :optional], :blknum},
      {"metadata", [:hash, :optional], :metadata},
      {"txtypes", [list: &to_tx_type/1, max_length: @max_tx_types, optional: true], :txtypes},
      {"limit", [pos_integer: true, lesser: 1000, optional: true], :limit},
      {"page", [:pos_integer, :optional], :page}
    ]

    Enum.reduce_while(constraints, {:ok, []}, fn {key, validators, atom}, {:ok, list} ->
      case expect(params, key, validators) do
        {:ok, nil} ->
          {:cont, {:ok, list}}

        {:ok, value} ->
          {:cont, {:ok, [{atom, value} | list]}}

        error ->
          {:halt, error}
      end
    end)
  end

  defp to_tx_type(tx_type_str) do
    expect(%{"txtype" => tx_type_str}, "txtype", :non_neg_integer)
  end
end
