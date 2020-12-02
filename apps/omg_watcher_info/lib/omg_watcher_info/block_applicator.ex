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

defmodule OMG.WatcherInfo.BlockApplicator do
  @moduledoc """
  Handles new block applications from Watcher's `BlockGetter` and persists them for further processing
  """

  alias OMG.WatcherInfo.DB

  @doc """
  Inserts a block to pending blocks, does not break when block already exists.
  """
  @spec insert_block!(OMG.Watcher.BlockGetter.BlockApplication.t()) :: :ok
  def insert_block!(block) do
    block
    |> to_pending_block()
    |> DB.PendingBlock.insert()
    |> case do
      {:ok, _} ->
        :ok

      # Ensures insert idempotency. Trying to add block with the same `blknum` that already exists takes no effect.
      # See also [comment](https://github.com/omgnetwork/elixir-omg/pull/1769#discussion_r528700434)
      {:error, changeset} ->
        [{:blknum, {_msg, [constraint: :unique, constraint_name: _name]}}] = changeset.errors()
        :ok
    end
  end

  defp to_pending_block(block) do
    data = %{
      eth_height: block.eth_height,
      blknum: block.number,
      blkhash: block.hash,
      timestamp: block.timestamp,
      transactions: block.transactions
    }

    %{
      data: :erlang.term_to_binary(data),
      blknum: block.number
    }
  end
end
