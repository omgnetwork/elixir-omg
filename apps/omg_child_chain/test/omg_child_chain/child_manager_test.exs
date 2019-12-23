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

defmodule OMG.ChildChain.ChildManagerTest do
  use ExUnit.Case, async: true
  alias OMG.ChildChain.ChildManager

  test "that the process starts, sends a checkin to us and shuts down" do
    # start a mock module so that the child manager has someone to report to
    {:ok, _} = __MODULE__.Monitor.start(self())
    {:ok, pid} = ChildManager.start_link(monitor: __MODULE__.Monitor)
    # when does the mananger send a health check?
    %{timer: timer} = :sys.get_state(pid)
    # we wait for that long
    assert_receive(:got_health_checkin, timer + 10)
    # make sure child manager has shutdown
    assert Process.alive?(pid) == false
  end

  defmodule Monitor do
    use GenServer

    def start(parent) do
      GenServer.start(__MODULE__, [parent], name: __MODULE__)
    end

    def init([parent]) do
      {:ok, parent}
    end

    def health_checkin() do
      GenServer.cast(__MODULE__, :health_checkin)
    end

    def handle_cast(:health_checkin, state) do
      _ = send(state, :got_health_checkin)
      {:stop, :normal, state}
    end
  end
end
