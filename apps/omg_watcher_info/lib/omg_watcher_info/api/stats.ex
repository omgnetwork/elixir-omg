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
        all_time: get_average_block_interval_all_time(),
        last_24_hours: get_average_block_interval_between(start_datetime_24_hours, end_datetime)
      }
    }

    {:ok, response}
  end

  @doc """
  Calculates the all-time average block interval.
  """
  @spec get_average_block_interval_all_time() :: float() | nil
  def get_average_block_interval_all_time() do
    block_count = Block.count_all()

    case block_count do
      n when n < 2 ->
        nil

      _ ->
        %{:max => max, :min => min} = Block.get_timestamp_range_all()

        # Formula for average of difference

        max
        |> Kernel.-(min)
        |> Kernel./(block_count - 1)
    end
  end

  @doc """
  Calculates the average block interval between two given timestamps.
  """
  @spec get_average_block_interval_between(non_neg_integer(), non_neg_integer()) ::
          float() | nil
  def get_average_block_interval_between(start_datetime, end_datetime) do
    block_count = Block.count_all_between_timestamps(start_datetime, end_datetime)

    case block_count do
      n when n < 2 ->
        nil

      _ ->
        %{:max => max, :min => min} = Block.get_timestamp_range_between(start_datetime, end_datetime)

        # Formula for average of difference

        max
        |> Kernel.-(min)
        |> Kernel./(block_count - 1)
    end
  end
end
