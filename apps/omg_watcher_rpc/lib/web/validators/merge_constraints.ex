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

defmodule OMG.WatcherRPC.Web.Validator.MergeConstraints do
  @moduledoc """
  Validates `/transaction.merge` parameters
  """

  alias OMG.Utils.HttpRPC.Validator.Base
  alias OMG.WatcherRPC.Web.Validator.Helpers

  import OMG.Utils.HttpRPC.Validator.Base

  require OMG.State.Transaction.Payment

  @doc """
  Parses and validates request body for `/transaction.merge`
  """
  @spec parse(map()) :: {:ok, Keyword.t()} | Base.validation_error_t()
  def parse(params) do
    with {:ok, constraints} <- get_constraints(params),
         {:ok, result} <- Helpers.validate_constraints(params, constraints) do
      {:ok, result}
    end
  end

  defp get_constraints(params) do
    case params do
      %{"address" => _, "currency" => _} ->
        {:ok, [{"address", [:address], :address}, {"currency", [:currency], :currency}]}

      %{"utxo_positions" => _} ->
        {:ok, [{"utxo_positions", [min_length: 2, max_length: 4, list: &to_utxo_pos/1], :utxo_positions}]}

      _ ->
        {:error, :operation_bad_request}
    end
  end

  defp to_utxo_pos(utxo_pos_string) do
    expect(%{"utxo_pos" => utxo_pos_string}, "utxo_pos", :non_neg_integer)
  end
end
