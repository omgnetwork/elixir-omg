# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.Watcher.Web.Validator.Constrains do
  @moduledoc """
  Validates `/transaction.all` query parameters
  """

  import OMG.Utils.HttpRPC.Validator.Base

  @doc """
  Validates possible query constrains, stops on first error.
  """
  @spec parse(%{binary() => any()}) :: {:ok, Keyword.t()} | {:error, any()}
  def parse(params) do
    constrains = [
      address: [:address, :optional],
      limit: [:pos_integer, :optional],
      blknum: [:pos_integer, :optional],
      metadata: [:hash, :optional]
    ]

    constrains
    |> Enum.reduce_while({:ok, []}, fn {constrain, validators}, {:ok, list} ->
      with {:ok, value} when not is_nil(value) <- expect(params, Atom.to_string(constrain), validators) do
        {:cont, {:ok, [{constrain, value} | list]}}
      else
        {:ok, nil} -> {:cont, {:ok, list}}
        error -> {:halt, error}
      end
    end)
  end
end
