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

defmodule OMG.Status.Alert.AlarmPrinterTest do
  use ExUnit.Case, async: false
  alias OMG.Status.AlarmPrinter

  @moduletag :common

  setup do
    {:ok, alarm_printer} = AlarmPrinter.start_link(alarm_module: __MODULE__.Alarm)

    %{alarm_printer: alarm_printer}
  end

  test "if the process has a previous backoff set", %{alarm_printer: alarm_printer} do
    :erlang.trace(alarm_printer, true, [:receive])
    %{previous_backoff: previous_backoff} = :sys.get_state(alarm_printer)
    assert is_number(previous_backoff)
  end

  test "that the process sends itself a message after startup", %{alarm_printer: alarm_printer} do
    %{previous_backoff: previous_backoff} = :sys.get_state(alarm_printer)
    parent = self()
    :dbg.start()
    {:ok, _} = :dbg.tracer(:process, {fn msg, _ -> send(parent, msg) end, []})
    :dbg.p(alarm_printer, :send)
    :ok = Process.sleep(previous_backoff)
    result = Enum.count(find_warn_print(alarm_printer, __MODULE__.Alarm.all()))
    assert result == Enum.count(__MODULE__.Alarm.all())
  end

  test "that the process increases the backoff", %{alarm_printer: alarm_printer} do
    %{previous_backoff: previous_backoff} = :sys.get_state(alarm_printer)
    assert is_number(previous_backoff)
    :dbg.stop_clear()
    parent = self()
    {:ok, _} = :dbg.tracer(:process, {fn msg, _ -> send(parent, msg) end, []})
    {:ok, _} = :dbg.p(alarm_printer, [:c])
    {:ok, _} = :dbg.tp(OMG.Status.AlarmPrinter, :handle_info, 2, [])

    receive do
      _ ->
        Process.sleep(previous_backoff)
    end

    min = previous_backoff
    max = 3 * previous_backoff
    %{previous_backoff: new_backoff} = :sys.get_state(alarm_printer)
    assert min < new_backoff and new_backoff < max
    :dbg.stop_clear()
    ### check if backoff is increasing
    Enum.each(1..5, fn _ ->
      %{previous_backoff: backoff} = :sys.get_state(alarm_printer)
      :print_alarms = send(alarm_printer, :print_alarms)
      min = backoff
      max = backoff * 3
      %{previous_backoff: new_backoff} = :sys.get_state(alarm_printer)
      assert min < new_backoff and new_backoff < max
    end)
  end

  defp find_warn_print(alarm_printer, alarms) do
    find_warn_print(alarm_printer, alarms, [])
  end

  defp find_warn_print(_alarm_printer, [], acc), do: acc

  defp find_warn_print(alarm_printer, [alarm | alarms] = all_alarms, acc) do
    message = "An alarm was raised #{alarm}"

    receive do
      {:trace, ^alarm_printer, :send, {_, {:warn, _, {Logger, ^message, _, _}}}, Logger} ->
        find_warn_print(alarm_printer, alarms, [:match | acc])

      _ ->
        find_warn_print(alarm_printer, all_alarms, acc)
    end
  end

  defmodule Alarm do
    def all(), do: [1, 2, 3]
  end
end
