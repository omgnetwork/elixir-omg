# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.Performance.ByzantineEvents.DoSExitWorker do
  @moduledoc """
  Contains a functions performing specified task (e.g. standard exit) that can be run in parallel by `ByzantineEvents`
  """

  alias OMG.Performance.HttpRPC.WatcherClient

  @doc """
  Returns a worker function that fetches all exits data in random order
  """
  def get_exits_fun(exit_positions, watcher_url) do
    worker = fn exit_positions ->
      Enum.map(exit_positions, &get_exit_data(&1, watcher_url))
    end

    fn ->
      exit_positions = Enum.shuffle(exit_positions)
      :timer.tc(fn -> worker.(exit_positions) end)
    end
  end

  defp get_exit_data(utxo_pos, watcher_url) do
    WatcherClient.get_exit_data(utxo_pos, watcher_url)
  rescue
    error -> error
  end
end
