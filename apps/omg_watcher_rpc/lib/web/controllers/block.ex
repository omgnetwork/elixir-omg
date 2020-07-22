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
    with {:ok, _block} <- Validator.BlockConstraints.parse_to_validate(params),
         {:ok, _block} <- validate_stateless(params),
         {:ok, block} <- validate_stateful(params) do
      api_response(block, conn, :validate_block)
    end
  end

  @doc """
  Verifies that all transactions are correctly formed.
  Verifies that given Merkle root matches reconstructed Merkle root.
  """
  def validate_stateless(params) do
    with {:ok, _block} <- validate_merkle_root(params),
         {:ok, block} <- validate_correctly_formed_transactions(params),
         do: {:ok, block}
  end

  def validate_correctly_formed_transactions(params) do
  end

  def validate_merkle_root(
        %{"hash" => merkle_root_hash, "transactions" => transactions, "number" => number} = block
      ) do
    %{hash: reconstructed_merkle_root_hash} =
      transactions
      |> Enum.map(&OMG.Eth.Encoding.from_hex/1)
      |> Enum.map(fn tx ->
        {:ok, recovered_tx} = OMG.State.Transaction.Recovered.recover_from(tx)
        recovered_tx
      end)
      |> OMG.Block.hashed_txs_at(number)

    case merkle_root_hash == reconstructed_merkle_root_hash do
      true -> {:ok, block}
      _ -> {:error, :unmatched_merkle_root}
    end
  end

  @doc """
  """
  defp validate_stateful(block) do
  end
end
