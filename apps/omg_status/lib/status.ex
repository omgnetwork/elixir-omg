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

defmodule OMG.Status do
  @moduledoc """
  An interface towards the node health.
  """
  alias OMG.Status.Alert.AlarmHandler
  @health_match for n <- [:boot_in_progress, :ethereum_client_connection], do: {{n, 0}, [], [false]}

  @spec is_healthy() :: boolean()
  def is_healthy() do
    case :ets.select(AlarmHandler.table_name(), @health_match) do
      [] -> false
      _ -> true
    end
  end
end

# :ets.new(OMG.Status.Alert.AlarmHandler.table_name, [:named_table, :set, :public, read_concurrency: true])
# :ets.update_counter(OMG.Status.Alert.AlarmHandler.table_name, :ethereum_client_connection, {2, 1, 1, 1}, {:ethereum_client_connection, 0})

# :ets.update_counter(OMG.Status.Alert.AlarmHandler.table_name, :ethereum_client_connection, {2, -1, 0, 0}, {:ethereum_client_connection, 1})
# a = [
#   {{:ethereum_client_connection, 1}, [], [true]},
#   {{:boot_in_progress, 1}, [], [true]},
#   {:_, [], [false]}
# ]
# :ets.select(OMG.Status.Alert.AlarmHandler.table_name, a)

# a = [
#   {{:ethereum_client_connection, 1}, [], [true]},
#   {:_, [], [false]}
# ]
