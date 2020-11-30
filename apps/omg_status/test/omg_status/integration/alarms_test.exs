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

defmodule OMG.Status.Alert.AlarmTest do
  use ExUnit.Case, async: false
  alias OMG.Status.Alert.Alarm

  @moduletag :integration
  @moduletag :common
  @moduletag timeout: 240_000

  setup_all do
    {:ok, apps} = Application.ensure_all_started(:omg_status)

    on_exit(fn ->
      apps |> Enum.reverse() |> Enum.each(&Application.stop/1)
    end)

    :ok
  end

  setup do
    Alarm.clear_all()
  end

  test "raise and clear alarm based only on id" do
    alarm = {:id, "details"}
    :alarm_handler.set_alarm(alarm)
    assert get_alarms([:id]) == [alarm]
    :alarm_handler.clear_alarm(alarm)
    assert get_alarms([:id]) == []
  end

  test "raise and clear alarm based on full alarm" do
    alarm = {:id5, %{a: 12, b: 34}}
    :alarm_handler.set_alarm(alarm)
    assert get_alarms([:id5]) == [alarm]
    :alarm_handler.clear_alarm({:id5, %{a: 12, b: 666}})
    assert get_alarms([:id5]) == [alarm]
    :alarm_handler.clear_alarm(alarm)
    assert get_alarms([:id5]) == []
  end

  test "adds and removes alarms" do
    # we *do* (unifying them under one app) want system alarms (like CPU, memory...)
    :alarm_handler.set_alarm({:some_system_alarm, "description_1"})
    assert not Enum.empty?(get_alarms([:some_system_alarm]))
    Alarm.clear_all()
    Alarm.set(Alarm.ethereum_connection_error(__MODULE__))
    assert Enum.count(get_alarms([:some_system_alarm, :ethereum_connection_error])) == 1

    Alarm.set(Alarm.ethereum_connection_error(__MODULE__.SecondProcess))
    assert Enum.count(get_alarms([:some_system_alarm, :ethereum_connection_error])) == 2

    Alarm.clear(Alarm.ethereum_connection_error(__MODULE__))
    assert Enum.count(get_alarms([:some_system_alarm, :ethereum_connection_error])) == 1

    Alarm.clear_all()
    assert Enum.empty?(get_alarms([:some_system_alarm, :ethereum_connection_error])) == true
  end

  test "an alarm raise twice is reported once" do
    Alarm.set(Alarm.ethereum_connection_error(__MODULE__))
    first_count = Enum.count(get_alarms([:ethereum_connection_error]))
    Alarm.set(Alarm.ethereum_connection_error(__MODULE__))
    ^first_count = Enum.count(get_alarms([:ethereum_connection_error]))
  end

  test "memsup alarms" do
    # memsup set alarm
    :alarm_handler.set_alarm({:system_memory_high_watermark, []})

    assert Enum.any?(Alarm.all(), &(elem(&1, 0) == :system_memory_high_watermark))
  end

  # we need to filter them because of unwanted system alarms, like high memory threshold
  # so we send the alarms we want to find in the args
  defp get_alarms(ids), do: Enum.filter(Alarm.all(), fn {id, _desc} -> id in ids end)
end
