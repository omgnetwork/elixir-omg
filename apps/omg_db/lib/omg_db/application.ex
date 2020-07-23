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

defmodule OMG.DB.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children = [
      OMG.DB.child_spec(),
      {OMG.DB.Monitor, [check_interval_ms: 5 * 60 * 1000]}
    ]

    opts = [strategy: :one_for_one, name: OMG.DB.Supervisor]

    Supervisor.start_link(children, opts)
  end

  def start_phase(:attach_telemetry, :normal, _phase_args) do
    handlers = [["measure-db", OMG.DB.Measure.supported_events(), &OMG.DB.Measure.handle_event/4, nil]]

    Enum.each(handlers, fn handler ->
      case apply(:telemetry, :attach_many, handler) do
        :ok -> :ok
        {:error, :already_exists} -> :ok
      end
    end)
  end
end
