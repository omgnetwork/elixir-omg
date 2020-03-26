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

    on_exit(fn ->
      :dbg.stop_clear()
    end)

    %{alarm_printer: alarm_printer}
  end

  test "if the process has a previous backoff set", %{alarm_printer: alarm_printer} do
    :erlang.trace(alarm_printer, true, [:receive])
    %{previous_backoff: previous_backoff} = :sys.get_state(alarm_printer)
    assert is_number(previous_backoff)
  end

  test "that the process sends itself a message after startup", %{alarm_printer: alarm_printer} do
    %{previous_backoff: previous_backoff} = :sys.get_state(alarm_printer)
    :erlang.trace(alarm_printer, true, [:send])
    :ok = Process.sleep(previous_backoff)
    assert_receive {:trace, _, :send, {:notify, {:warn, _, {Logger, "An alarm was raised 1", {_, _}, _}}}, Logger}
    assert_receive {:trace, _, :send, {:notify, {:warn, _, {Logger, "An alarm was raised 2", {_, _}, _}}}, Logger}
    assert_receive {:trace, _, :send, {:notify, {:warn, _, {Logger, "An alarm was raised 3", {_, _}, _}}}, Logger}
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

  defmodule Alarm do
    def all(), do: [1, 2, 3]
  end
end
