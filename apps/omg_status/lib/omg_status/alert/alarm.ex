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
  Interface for raising and clearing alarms related to OMG Status.
  """
  alias OMG.Status.Alert.AlarmHandler

  @typedoc """
  The raw alarm being used to `set` the Alarm
  """
  @type alarm_detail :: %{
          node: Node.t(),
          reporter: module()
        }

  @type alarms ::
          {:boot_in_progress
           | :ethereum_client_connection
           | :invalid_fee_file
           | :statsd_client_connection
           | :chain_crash, alarm_detail}

  def alarm_types(),
    do: [:boot_in_progress, :ethereum_client_connection, :invalid_fee_file, :statsd_client_connection, :chain_crash]

  @spec statsd_client_connection(module()) :: {:statsd_client_connection, alarm_detail}
  def statsd_client_connection(reporter),
    do: {:statsd_client_connection, %{node: Node.self(), reporter: reporter}}

  @spec ethereum_client_connection(module()) :: {:ethereum_client_connection, alarm_detail}
  def ethereum_client_connection(reporter),
    do: {:ethereum_client_connection, %{node: Node.self(), reporter: reporter}}

  @spec boot_in_progress(module()) :: {:boot_in_progress, alarm_detail}
  def boot_in_progress(reporter),
    do: {:boot_in_progress, %{node: Node.self(), reporter: reporter}}

  @spec invalid_fee_file(module()) :: {:invalid_fee_file, alarm_detail}
  def invalid_fee_file(reporter),
    do: {:invalid_fee_file, %{node: Node.self(), reporter: reporter}}

  @spec chain_crash(module()) :: {:chain_crash, alarm_detail}
  def chain_crash(reporter),
    do: {:chain_crash, %{node: Node.self(), reporter: reporter}}

  @spec set(alarms()) :: :ok | :duplicate
  def set(alarm), do: do_raise(alarm)

  @spec clear(alarms()) :: :ok | :not_raised
  def clear(alarm), do: do_clear(alarm)

  def clear_all do
    Enum.each(all(), &:alarm_handler.clear_alarm(&1))
  end

  def all do
    :gen_event.call(:alarm_handler, AlarmHandler, :get_alarms)
  end

  defp do_raise(alarm) do
    if Enum.member?(all(), alarm) do
      :duplicate
    else
      :alarm_handler.set_alarm(alarm)
    end
  end

  defp do_clear(alarm) do
    if Enum.member?(all(), alarm) do
      :alarm_handler.clear_alarm(alarm)
    else
      :not_raised
    end
  end
end
