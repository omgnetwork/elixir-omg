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

defmodule OMG.WatcherRPC.Web.Validator.Helpers do
  @moduledoc """
  helper for validators
  """
  import OMG.Utils.HttpRPC.Validator.Base, only: [expect: 3]

  @doc """
  Validates possible params with query constraints, stops on first error.
  """
  @spec validate_constraints(%{binary() => any()}, list()) :: {:ok, Keyword.t()} | {:error, any()}
  def validate_constraints(params, constraints) do
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
end
