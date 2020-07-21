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

defmodule OMG.WatcherRPC.Web.Validator.BlockConstraints do
  @moduledoc """
  Validates `/block.all` query parameters
  """

  use OMG.WatcherRPC.Web, :controller
  alias OMG.WatcherRPC.Web.Validator.Helpers

  @doc """
  Validates possible query constraints, stops on first error.
  """
  @spec parse(%{binary() => any()}) :: {:ok, Keyword.t()} | {:error, any()}
  def parse(params) do
    constraints = [
      {"limit", [pos_integer: true, lesser: 1000, optional: true], :limit},
      {"page", [:pos_integer, :optional], :page}
    ]

    Helpers.validate_constraints(params, constraints)
  end

  @spec parse_block(map) :: {:error, {:validation_error, binary, any}} | {:ok, map}
  def parse_block(block) do
    with {:ok, _hash} <- expect(block, "hash", :hash),
         {:ok, _transactions} <- expect(block, "transactions", list: &is_hex/1),
         do: {:ok, block}
  end

  defp is_hex(original) do
    expect(%{"hash" => original}, "hash", :hex)
  end
end
