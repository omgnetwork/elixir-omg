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

defmodule OMG.Status.Application do
  @moduledoc """
  Top level application module.
  """
  use Application

  alias OMG.Status.AlarmPrinter
  alias OMG.Status.Alert.Alarm
  alias OMG.Status.Alert.AlarmHandler
  alias OMG.Status.Configuration
  alias OMG.Status.DatadogEvent.AlarmConsumer
  alias OMG.Status.Metric.Datadog
  alias OMG.Status.Metric.VmstatsSink

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    system_memory_check_interval_ms = Configuration.system_memory_check_interval_ms()
    system_memory_high_threshold = Configuration.system_memory_high_threshold()

    children =
      if Configuration.datadog_disabled?() do
        # spandex datadog api server is able to flush when disabled?: true
        [{SpandexDatadog.ApiServer, spandex_datadog_options()}]
      else
        [
          {OMG.Status.Monitor.StatsdMonitor, [alarm_module: Alarm, child_module: Datadog]},
          {OMG.Status.Monitor.MemoryMonitor,
           [
             alarm_module: Alarm,
             memsup_module: :memsup,
             threshold: system_memory_high_threshold,
             interval_ms: system_memory_check_interval_ms
           ]},
          VmstatsSink.prepare_child(),
          {SpandexDatadog.ApiServer, spandex_datadog_options()},
          {AlarmConsumer,
           [
             dd_alarm_handler: OMG.Status.DatadogEvent.AlarmHandler,
             release: Application.get_env(:omg_status, :release),
             current_version: Application.get_env(:omg_status, :current_version),
             publisher: OMG.Status.Metric.Datadog
           ]}
        ]
      end

    child = [{AlarmPrinter, [alarm_module: Alarm]}]
    Supervisor.start_link(children ++ child, strategy: :one_for_one, name: Status.Supervisor)
  end

  def start_phase(:install_alarm_handler, _start_type, _phase_args) do
    :ok = AlarmHandler.install()
  end

  defp spandex_datadog_options() do
    config = Application.get_all_env(:spandex_datadog)
    config_host = config[:host]
    config_port = config[:port]
    config_batch_size = config[:batch_size]
    config_sync_threshold = config[:sync_threshold]
    config_http = config[:http]
    spandex_datadog_options(config_host, config_port, config_batch_size, config_sync_threshold, config_http)
  end

  defp spandex_datadog_options(config_host, config_port, config_batch_size, config_sync_threshold, config_http) do
    [
      host: config_host || "localhost",
      port: config_port || 8126,
      batch_size: config_batch_size || 10,
      sync_threshold: config_sync_threshold || 100,
      http: config_http || HTTPoison
    ]
  end
end
