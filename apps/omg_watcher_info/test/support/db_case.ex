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

defmodule OMG.WatcherInfo.DBCase do
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias OMG.WatcherInfo.DB.Repo
  alias OMG.WatcherInfo

  using do
    quote do
      import OMG.WatcherInfo.Factory

      alias OMG.WatcherInfo.DB
    end
  end

  setup tags do
    {:ok, pid} =
      Supervisor.start_link(
        [%{id: Repo, start: {Repo, :start_link, []}, type: :supervisor}],
        strategy: :one_for_one,
        name: WatcherInfo.Supervisor
      )

    :ok = Sandbox.checkout(Repo)

    unless tags[:async] do
      Sandbox.mode(Repo, {:shared, self()})
    end

    # setup and body test are performed in one process, `on_exit` is performed in another
    on_exit(fn ->
      wait_for_process(pid)
      :ok
    end)

    :ok
  end

  defp wait_for_process(pid, timeout \\ :infinity) when is_pid(pid) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, _, _} ->
        :ok
    after
      timeout ->
        throw({:timeouted_waiting_for, pid})
    end
  end
end
