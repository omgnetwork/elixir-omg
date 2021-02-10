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

defmodule OMG.Status.Metric.DatadogTest do
  use ExUnit.Case, async: true
  alias OMG.Status.Metric.Datadog

  test "if exiting process/port sends an exit signal to the parent process" do
    parent = self()

    {:ok, _} =
      Task.start(fn ->
        {:ok, datadog_pid} = Datadog.start_link()
        port = Port.open({:spawn, "cat"}, [:binary])
        true = Process.link(datadog_pid)
        send(parent, {:data, port, datadog_pid})

        # we want to exit because the port forcefully closes
        # so this sleep shouldn't happen
        Process.sleep(10_000)
      end)

    receive do
      {:data, port, datadog_pid} ->
        :erlang.trace(datadog_pid, true, [:receive])
        true = Process.exit(port, :portkill)
        assert_receive {:trace, ^datadog_pid, :receive, {:EXIT, _port, :portkill}}
    end
  end
end
