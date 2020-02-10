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

defmodule OMG.ChildChain.API.AlarmTest do
  alias OMG.ChildChain.API.Alarm
  alias OMG.Status.Alert.AlarmHandler
  use ExUnit.Case, async: false

  setup_all do
    {:ok, apps} = Application.ensure_all_started(:omg_status)

    on_exit(fn ->
      apps |> Enum.reverse() |> Enum.each(fn app -> Application.stop(app) end)
    end)
  end

  setup %{} do
    system_alarm = {:system_memory_high_watermark, []}
    system_disk_alarm = {{:disk_almost_full, "/dev/null"}, []}
    app_alarm = {:ethereum_connection_error, %{node: Node.self(), reporter: Reporter}}

    on_exit(fn ->
      :alarm_handler.clear_alarm(app_alarm)
      :alarm_handler.clear_alarm(system_alarm)
      :alarm_handler.clear_alarm(system_disk_alarm)
    end)

    all = :gen_event.call(:alarm_handler, AlarmHandler, :get_alarms)
    :ok = Enum.each(all, &:alarm_handler.clear_alarm(&1))
    %{system_alarm: system_alarm, system_disk_alarm: system_disk_alarm, app_alarm: app_alarm}
  end

  test "if alarms are returned when there are no alarms raised", _ do
    all = :gen_event.call(:alarm_handler, AlarmHandler, :get_alarms)
    :ok = Enum.each(all, &:alarm_handler.clear_alarm(&1))
    {:ok, []} = Alarm.get_alarms()
  end

  test "if alarms are returned when there are alarms raised", %{
    system_alarm: system_alarm,
    system_disk_alarm: system_disk_alarm,
    app_alarm: app_alarm
  } do
    :alarm_handler.set_alarm(system_alarm)
    :alarm_handler.set_alarm(app_alarm)
    :alarm_handler.set_alarm(system_disk_alarm)

    {:ok,
     [
       {{:disk_almost_full, "/dev/null"}, []},
       {:ethereum_connection_error, %{node: :nonode@nohost, reporter: Reporter}},
       {:system_memory_high_watermark, []}
     ]} = Alarm.get_alarms()
  end
end
