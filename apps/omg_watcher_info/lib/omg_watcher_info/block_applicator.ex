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

  @type block_application_t :: %{
          eth_height: pos_integer(),
          hash: binary(),
          number: pos_integer(),
          timestamp: pos_integer(),
          transactions: [OMG.State.Transaction.Recovered.t()]
        }

  @doc """
  Inserts a block along with transactions and outputs, does not break when block already exists.
  """
  @spec insert_block!(block_application_t()) :: :ok
  def insert_block!(block) do
    block
    |> DB.Block.insert_from_block_application()
    |> case do
      {:ok, _} ->
        :ok

      # Ensures insert idempotency. Trying to add block with the same `blknum` that already exists takes no effect.
      # See also [comment](https://github.com/omgnetwork/elixir-omg/pull/1769#discussion_r528700434)
      {:error, "current_block", changeset, _explain} ->
        [{:blknum, {_msg, [constraint: :unique, constraint_name: _name]}}] = changeset.errors()
        :ok
    end
  end
end
