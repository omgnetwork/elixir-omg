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

  alias OMG.Block
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
    with {:ok, block} <- Validator.BlockValidator.parse_to_validate(params),
         {:ok, _block} <- stateless_validate(block) do
      api_response(block, conn, :validate_block)
    end
  end

  @spec stateless_validate(Block.t()) :: any
  defp stateless_validate(block) do
    with {:ok, block} <- Validator.BlockValidator.verify_merkle_root(block),
         {:ok, block} <- Validator.BlockValidator.verify_transactions(block.transactions) do
      {:ok, block}
    end
  end
end
