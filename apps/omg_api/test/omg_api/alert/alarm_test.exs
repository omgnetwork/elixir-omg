# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.API.Alert.AlarmTest do
  use ExUnit.Case, async: false
  alias OMG.API.Alert.Alarm
  alias OMG.API.Alert.AlarmHandler

  setup_all do
    :ok = AlarmHandler.install()
  end

  setup do
    Alarm.clear_all()
  end

  test "an alarm raise twice is reported once" do
    Alarm.raise({:ethereum_client_connection, Node.self(), __MODULE__})
    first_count = Enum.count(get_alarms([:ethereum_client_connection]))
    Alarm.raise({:ethereum_client_connection, Node.self(), __MODULE__})
    ^first_count = Enum.count(get_alarms([:ethereum_client_connection]))
  end

  test "system alarms are not part of OMG API" do
    :alarm_handler.set_alarm({:some_system_alarm, "description_1"})

    Alarm.raise({:ethereum_client_connection, Node.self(), __MODULE__})
    1 = length(Alarm.all())
  end

  test "adds and removes alarms" do
    # we don't want system alarms (like CPU, memory...)
    :alarm_handler.set_alarm({:some_system_alarm, "description_1"})
    assert Enum.empty?(get_alarms([:some_system_alarm]))

    Alarm.raise({:ethereum_client_connection, Node.self(), __MODULE__})
    assert Enum.count(get_alarms([:some_system_alarm, :ethereum_client_connection])) == 1

    Alarm.raise({:ethereum_client_connection, Node.self(), __MODULE__.SecondProcess})
    assert Enum.count(get_alarms([:some_system_alarm, :ethereum_client_connection])) == 2

    Alarm.clear({:ethereum_client_connection, Node.self(), __MODULE__})
    assert Enum.count(get_alarms([:some_system_alarm, :ethereum_client_connection])) == 1

    Alarm.clear_all()
    assert Enum.empty?(get_alarms([:some_system_alarm, :ethereum_client_connection])) == true
  end

  test "raising multiple alarms from different reporters and ensure they can be cleared" do
    alarm1 = {:ethereum_client_connection, Node.self(), __MODULE__}
    alarm2 = {:ethereum_client_connection, Node.self(), __MODULE__.SecondProcess}
    alarm3 = {:ethereum_client_connection, Node.self(), __MODULE__.ThirdProcess}
    Alarm.raise(alarm1)
    Alarm.raise(alarm2)
    Alarm.raise(alarm3)
    assert Enum.count(Alarm.all()) == 3
    Alarm.clear(alarm1)
    Alarm.clear(alarm2)
    Alarm.clear(alarm3)
    assert Enum.empty?(get_alarms([:ethereum_client_connection])) == true
  end

  # we need to filter them because of unwanted system alarms, like high memory threshold
  # so we send the alarms we want to find in the args
  defp get_alarms(ids), do: Enum.filter(Alarm.all(), fn %{id: id} -> id in ids end)
end
