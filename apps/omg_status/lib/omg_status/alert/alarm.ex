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

defmodule OMG.Status.Alert.Alarm do
  @moduledoc """
  Interface for raising and clearing alarms.
  """
  alias OMG.Status.Alert.AlarmHandler

  @typedoc """
  The raw alarm being used to `set` the Alarm
  """
  @type raw_t :: {atom(), list()} | {{atom(), binary()}, list} | {atom(), %{node: Node.t(), reporter: module()}}

  def clear_all do
    all_raw()
    |> Enum.each(&:alarm_handler.clear_alarm(&1))
  end

  def all, do: all_raw()

  defp all_raw, do: :gen_event.call(:alarm_handler, AlarmHandler, :get_alarms)
end
