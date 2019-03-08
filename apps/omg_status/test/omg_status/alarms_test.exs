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

defmodule OMG.Status.Alert.AlarmTest do
  use ExUnit.Case, async: false
  alias OMG.Status.Alert.Alarm

  setup do
    Alarm.clear_all()
  end

  test "raise and clear alarm based only on id" do
    :alarm_handler.set_alarm({{:id, "test"}, "details"})
    assert get_alarms([{:id, "test"}]) == [%{details: "details", id: {:id, "test"}}]
    :alarm_handler.clear_alarm({:id, "test"})
    assert get_alarms([{:id, "test"}]) == []
  end

  test "raise and clear alarm based on full alarm" do
    :alarm_handler.set_alarm({{:id, "test"}, %{a: 12, b: 34}})
    assert get_alarms([{:id, "test"}]) == [%{details: %{a: 12, b: 34}, id: {:id, "test"}}]
    :alarm_handler.clear_alarm({{:id, "test"}, %{a: 12, b: 666}})
    assert get_alarms([{:id, "test"}]) == [%{details: %{a: 12, b: 34}, id: {:id, "test"}}]
    :alarm_handler.clear_alarm({{:id, "test"}, %{a: 12, b: 34}})
    assert get_alarms([{:id, "test"}]) == []
  end

  @tag timeout: 240_000
  @tag :slow
  test "memsup alarms" do
    # check if memsup is running
    assert is_pid(GenServer.whereis(:memsup))
    # sets memory check limit to 100%
    # waits for next check so all previous alarm are cleared
    # sets memory check limit to 1%
    # see if memsup alarm was raised after next check
    :memsup.set_sysmem_high_watermark(1)
    :timer.sleep(:memsup.get_check_interval() + 1000)
    :memsup.set_sysmem_high_watermark(0.01)
    :timer.sleep(:memsup.get_check_interval() + 1000)
    assert Enum.any?(Alarm.all(), &(Map.get(&1, :id) == :system_memory_high_watermark))
  end

  # we need to filter them because of unwanted system alarms, like high memory threshold
  # so we send the alarms we want to find in the args
  defp get_alarms(ids), do: Enum.filter(Alarm.all(), fn %{id: id} -> id in ids end)
end
