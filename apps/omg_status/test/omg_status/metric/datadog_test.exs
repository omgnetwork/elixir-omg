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

defmodule OMG.Status.Metric.DatadogTest do
  use ExUnit.Case, async: true
  alias OMG.Status.Metric.Datadog

  setup do
    parent = self()

    spawn(fn ->
      {:ok, datadog_pid} = Datadog.start_link()
      send(parent, {:ok, datadog_pid})
    end)

    receive do
      {:ok, datadog_pid} ->
        %{datadog: {:ok, datadog_pid}}
    end
  end

  test "if exiting process/port sends an exit signal to the parent process", %{datadog: {:ok, datadog_pid}} do
    :erlang.trace(datadog_pid, true, [:receive])

    {:ok, _} =
      Task.start(fn ->
        port = Port.open({:spawn, "cat"}, [:binary])
        true = Process.link(datadog_pid)
        true = Process.exit(port, :portkill)

        # we want to exit because the port forcefully closes
        # so this sleep shouldn't happen
        Process.sleep(10_000)
      end)
  end
end
