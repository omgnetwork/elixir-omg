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

defmodule OMG.WatcherRPC.Web.Validator.TransactionConstraints do
  @moduledoc """
  Validates `/transaction.all` query parameters
  """

  import OMG.Utils.HttpRPC.Validator.Base

  @doc """
  Validates possible query constraints, stops on first error.
  """
  @spec parse(%{binary() => any()}) :: {:ok, Keyword.t()} | {:error, any()}
  def parse(params) do
    constraints = [
      "address" => [:address, :optional],
      "blknum" => [:pos_integer, :optional],
      "metadata" => [:hash, :optional],
      "limit" => [:pos_integer, :optional],
      "page" => [:pos_integer, :optional]
    ]

    Enum.reduce_while(constraints, {:ok, []}, fn {key, validators}, {:ok, list} ->
      case expect(params, key, validators) do
        {:ok, nil} -> {:cont, {:ok, list}}
        {:ok, value} -> {:cont, {:ok, [{String.to_existing_atom(key), value} | list]}}
        error -> {:halt, error}
      end
    end)
  end
end
