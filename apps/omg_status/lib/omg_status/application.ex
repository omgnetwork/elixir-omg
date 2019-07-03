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

defmodule OMG.Status.Application do
  @moduledoc """
  Top level application module.
  """
  use Application
  alias OMG.Status.Alert.AlarmHandler

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    import Telemetry.Metrics

    children =
      if is_enabled?() do
        [
          {Storage, %{}},
          {TelemetryMetricsStatsd,
           [
             metrics: [
               last_value("vm.memory.total"),
               last_value("vm.memory.processes"),
               last_value("vm.memory.processes_used"),
               last_value("vm.memory.atom_used"),
               last_value("vm.memory.binary"),
               last_value("vm.memory.ets"),
               last_value("vm.memory.system"),
               last_value("vm.memory.total"),
               last_value("vm.process.count"),
               last_value("vm.process.limit"),
               last_value("vm.port.count"),
               last_value("vm.port.limit"),
               last_value("vm.atom_count"),
               last_value("vm.modules"),
               last_value("vm.run_queue"),
               last_value("vm.messages_in_queues"),
               counter("vm.io.bytes_in"),
               counter("vm.io.bytes_out"),
               counter("vm.gc.count"),
               counter("vm.gc.words_reclaimed"),
               counter("vm.reductions"),
               summary("vm.scheduler_wall_time", tags: [:scheduler_id]),
               summary("vm.scheduler_wall_time.total", tags: [:scheduler_id])
             ],
             formatter: :datadog
           ]}
        ]
      else
        []
      end

    supervisor_result = Supervisor.start_link(children, strategy: :one_for_one, name: Status.Supervisor)

    if is_enabled?() do
      :telemetry_poller.start_link(
        measurements: [
          :memory,
          {Status.Metric.Measurements, :all, []}
        ]
      )
    end

    supervisor_result
  end

  def start_phase(:install_alarm_handler, _start_type, _phase_args) do
    :ok = AlarmHandler.install()
  end

  @spec is_enabled?() :: boolean() | nil
  defp is_enabled?() do
    case {Application.get_env(:omg_status, :metrics), System.get_env("METRICS")} do
      {true, _} -> true
      {_, "true"} -> true
      {false, _} -> false
      {_, "false"} -> false
      _ -> nil
    end
  end
end
