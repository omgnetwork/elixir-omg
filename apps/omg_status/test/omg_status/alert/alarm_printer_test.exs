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
  import ExUnit.CaptureLog, only: [capture_log: 1]

  alias OMG.Status.AlarmPrinter

  @moduletag :common

  setup do
    {:ok, alarm_printer} = AlarmPrinter.start_link(alarm_module: __MODULE__.Alarm)

    %{alarm_printer: alarm_printer}
  end

  test "if the process has a previous backoff set", %{alarm_printer: alarm_printer} do
    assert capture_log(fn ->
             :erlang.trace(alarm_printer, true, [:receive])
             %{previous_backoff: previous_backoff} = :sys.get_state(alarm_printer)
             assert is_number(previous_backoff)
           end)
  end

  test "that the process sends itself a message after startup", %{alarm_printer: alarm_printer} do
    assert capture_log(fn ->
             %{previous_backoff: previous_backoff} = :sys.get_state(alarm_printer)
             :erlang.trace(alarm_printer, true, [:send])
             :ok = Process.sleep(previous_backoff)

             assert_receive {:trace, _, :send, {:notify, {:warn, _, {Logger, "An alarm was raised 1", {_, _}, _}}},
                             Logger}

             assert_receive {:trace, _, :send, {:notify, {:warn, _, {Logger, "An alarm was raised 2", {_, _}, _}}},
                             Logger}

             assert_receive {:trace, _, :send, {:notify, {:warn, _, {Logger, "An alarm was raised 3", {_, _}, _}}},
                             Logger}
           end)
  end

  test "that the process increases the backoff", %{alarm_printer: alarm_printer} do
    assert capture_log(fn ->
             %{previous_backoff: previous_backoff} = :sys.get_state(alarm_printer)
             :erlang.trace(alarm_printer, true, [:send])
             :ok = Process.sleep(previous_backoff)

             assert_receive {:trace, _, :send, {:notify, {:warn, _, {Logger, "An alarm was raised 1", {_, _}, _}}},
                             Logger}

             assert_receive {:trace, _, :send, {:notify, {:warn, _, {Logger, "An alarm was raised 2", {_, _}, _}}},
                             Logger}

             assert_receive {:trace, _, :send, {:notify, {:warn, _, {Logger, "An alarm was raised 3", {_, _}, _}}},
                             Logger}

             %{previous_backoff: previous_backoff_1} = :sys.get_state(alarm_printer)
             assert previous_backoff_1 > previous_backoff
           end)
  end

  defmodule Alarm do
    def all(), do: [1, 2, 3]
  end
end
