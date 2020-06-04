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

defmodule OMG.WatcherInfo.PendingBlockProcessor.Storage do
  @moduledoc """
  Contains storage related functions of the PendingBlockProcessor
  """

  alias OMG.WatcherInfo.DB.Block
  alias OMG.WatcherInfo.DB.PendingBlock

  def check_queue() do
    case PendingBlock.get_next_to_process() do
      nil ->
        :ok

      block ->
        process_block(block)
        check_queue()
    end
  end

  defp process_block(block) do
    case Block.insert_pending_block(block) do
      {:ok, _} ->
        :ok

      _error ->
        PendingBlock.increment_retry_count(block)
        :error
    end
  end
end
