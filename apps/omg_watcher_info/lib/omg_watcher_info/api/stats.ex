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

defmodule OMG.WatcherInfo.API.Stats do
  @moduledoc """
  Module provides operations related to network statistics.
  """

  alias OMG.WatcherInfo.DB.{Block, Transaction}

  @doc """
  Retrieves network statistics.
  """
  def get() do
    timestamps_all_time = Block.get_timestamps()
    timestamps_last_24_hours = Block.get_timestamps_last_24_hours()

    response = %{
      transaction_count: %{
        all_time: Transaction.get_count(),
        last_24_hours: Transaction.get_count_last_24_hour()
      },
      block_count: %{
        all_time: Block.get_count(),
        last_24_hours: Block.get_count_last_24_hour()
      },
      average_block_interval: %{
        all_time: get_average_block_interval(timestamps_all_time),
        last_24_hours: get_average_block_interval(timestamps_last_24_hours)
      }
    }

    {:ok, response}
  end

  @spec get_average_block_interval([%{timestamp: integer}]) :: float | String.t()
  def get_average_block_interval(timestamps) do
    case length(timestamps) do
      n when n < 2 ->
        String.to_atom("N/A")

      n when n >= 2 ->
        timestamps
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [a, b] -> b.timestamp - a.timestamp end)
        |> average()
    end
  end

  @spec average([integer]) :: float
  def average(diff_array) do
    diff_array
    |> Enum.reduce(0, fn current, acc -> current + acc end)
    |> Kernel./(length(diff_array))
  end
end
