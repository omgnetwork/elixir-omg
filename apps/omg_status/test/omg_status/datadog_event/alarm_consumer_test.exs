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

defmodule OMG.Status.DatadogEvent.AlarmConsumerTest do
  @moduledoc false

  use ExUnit.Case, async: true
  alias OMG.Status.DatadogEvent.AlarmConsumer
  @alarm_details %{test_pid: :test_case_1}
  setup_all do
    {:ok, _pid} = :gen_event.start_link({:local, __MODULE__.DatadogAlarmMock})
    :ok
  end

  setup do
    start_supervised(
      AlarmConsumer.prepare_child(
        alarm_handler: __MODULE__.DatadogAlarmMock,
        dd_alarm_handler: __MODULE__.DatadogAlarmHandlerMock,
        release: "child_chain_or_watcher",
        current_version: "test-123",
        publisher: __MODULE__.DatadogEventMock
      )
    )

    :ok
  end

  test "if a event message put on omg bus is consumed by the event consumer and published on the publisher interface" do
    %{test_pid: test_pid_name} = @alarm_details
    true = Process.register(self(), test_pid_name)
    alarm = {:ethereum_connection_error, @alarm_details}
    __MODULE__.DatadogAlarmMock.set_alarm(alarm)
    assert_receive :event
  end

  defmodule DatadogEventMock do
    # we've put the this test process identifieer into the alarm details
    # message is a binary string "%{test_pid: :test_case_1}"
    def event(_title, "%{test_pid: :" <> rest = _message, _options) do
      <<test_pid_name::binary-size(11), _::binary>> = rest
      # test_pid_name should now be ":test_case_1"
      Kernel.send(String.to_existing_atom(test_pid_name), :event)
    end
  end

  defmodule DatadogAlarmHandlerMock do
    def init([alarm_consumer_process]) do
      {:ok, alarm_consumer_process}
    end

    def handle_event({:set_alarm, {:ethereum_connection_error, _details}} = alarm, alarm_consumer_process) do
      :ok = GenServer.cast(alarm_consumer_process, alarm)
      {:ok, alarm_consumer_process}
    end

    def handle_event({:clear_alarm, {:ethereum_connection_error, _details}} = alarm, alarm_consumer_process) do
      :ok = GenServer.cast(alarm_consumer_process, alarm)
      {:ok, alarm_consumer_process}
    end
  end

  defmodule DatadogAlarmMock do
    def init(_) do
      {:ok, []}
    end

    def add_alarm_handler(module, args) do
      :gen_event.add_handler(__MODULE__, module, args)
    end

    def set_alarm(alarm) do
      :gen_event.notify(__MODULE__, {:set_alarm, alarm})
    end

    def clear_alarm(alarm_id) do
      :gen_event.notify(__MODULE__, {:clear_alarm, alarm_id})
    end
  end
end
