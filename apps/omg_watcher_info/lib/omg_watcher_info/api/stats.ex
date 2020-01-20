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
    response = %{
      transactions: %{
        count: %{
          all_time: Transaction.get_count(),
          last_24_hours: Transaction.get_count_last_24_hour()
        }
      },
      blocks: %{
        all_time: Block.get_count(),
        last_24_hours: Block.get_count_last_24_hour()
      }
    }

    {:ok, response}
  end
end
