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

defmodule OMG.WatcherRPC.Web.Controller.Block do
  @moduledoc """
  Operations related to block.
  """

  use OMG.WatcherRPC.Web, :controller

  alias OMG.Watcher
  alias OMG.WatcherInfo.API.Block, as: InfoApiBlock
  alias OMG.WatcherRPC.Web.Validator

  @doc """
  Retrieves a specific block by block number.
  """
  def get_block(conn, params) do
    with {:ok, blknum} <- expect(params, "blknum", :pos_integer) do
      blknum
      |> InfoApiBlock.get()
      |> api_response(conn, :block)
    end
  end

  @doc """
  Retrieves a list of most recent blocks
  """
  def get_blocks(conn, params) do
    with {:ok, constraints} <- Validator.BlockConstraints.parse(params) do
      constraints
      |> InfoApiBlock.get_blocks()
      |> api_response(conn, :blocks)
    end
  end

  @doc """
  Executes stateful and stateless validation of a block.
  """
  def validate_block(conn, params) do
    with {:ok, block} <- Validator.BlockConstraints.parse_to_validate(params) do
      case Watcher.BlockValidator.stateless_validate(block) do
        {:ok, true} ->
          api_response(%{valid: true, error: nil}, conn, :validate_block)

        {:error, reason} ->
          api_response(%{valid: false, error: reason}, conn, :validate_block)
      end
    end
  end
end
