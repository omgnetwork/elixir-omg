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

defmodule OMG.Status do
  @moduledoc """
  An interface towards the node health for RPC requests.
  For the RPC to work we need Ethereum client connectivity and booting should not be in progress.
  """
  alias OMG.Status.Alert.AlarmHandler

  # this can be read as
  # if ETS table has a tuple entry in form of {:boot_in_progress, 0}, return false
  # if ETS table has a tuple entry in form of {:boot_in_progress, 1}, return true
  @health_match List.flatten(
                  for n <- [:boot_in_progress, :ethereum_client_connection, :main_supervisor_halted],
                      do: [{{n, 0}, [], [false]}, {{n, 1}, [], [true]}]
                )

  @spec is_healthy() :: boolean()
  def is_healthy() do
    # the selector returns true when an alarm is raised
    # the selector returns false when an alarm is not raised
    # one alarm is enough to say we're not healthy
    not Enum.member?(:ets.select(AlarmHandler.table_name(), @health_match), true)
  end
end
