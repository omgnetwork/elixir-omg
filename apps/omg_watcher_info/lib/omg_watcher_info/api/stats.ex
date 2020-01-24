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

  alias OMG.WatcherInfo.DB.Block
  alias OMG.WatcherInfo.DB.Transaction

  @seconds_in_twenty_four_hours 86_400

  @doc """
  Retrieves network statistics.
  """
  def get() do
    end_datetime = DateTime.to_unix(DateTime.utc_now())
    start_datetime_24_hours = end_datetime - @seconds_in_twenty_four_hours

    timestamps_all_time = Block.all_timestamps()
    timestamps_24_hours = Block.all_timestamps_between(start_datetime_24_hours, end_datetime)

    response = %{
      transaction_count: %{
        all_time: Transaction.count_all(),
        last_24_hours: Transaction.count_all_between_timestamps(start_datetime_24_hours, end_datetime)
      },
      block_count: %{
        all_time: Block.count_all(),
        last_24_hours: Block.count_all_between_timestamps(start_datetime_24_hours, end_datetime)
      },
      average_block_interval_seconds: %{
        all_time: get_average_block_interval(timestamps_all_time),
        last_24_hours: get_average_block_interval(timestamps_24_hours)
      }
    }

    {:ok, response}
  end

  @doc """
  Calculates the average of the differences between timestamps.
  """
  @spec get_average_block_interval([%{timestamp: non_neg_integer()}]) :: float | String.t()
  def get_average_block_interval(timestamps) do
    case timestamps do
      [_, _ | _] ->
        first =
          timestamps
          |> List.first()
          |> Map.get(:timestamp)

        last =
          timestamps
          |> List.last()
          |> Map.get(:timestamp)

        # Formula for average of difference
        (last - first) / (length(timestamps) - 1)

      _ ->
        nil
    end
  end
end
