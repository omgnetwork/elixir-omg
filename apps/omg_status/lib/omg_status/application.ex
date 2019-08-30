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
  alias OMG.Status.Alert.Alarm
  alias OMG.Status.Alert.AlarmHandler
  alias OMG.Status.Metric.Datadog
  alias OMG.Status.Metric.VmstatsSink

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    :ok = DeferredConfig.populate(:spandex_datadog)
    :ok = DeferredConfig.populate(:statix)
    :ok = DeferredConfig.populate(:omg_status)
    datadog = is_disabled?()

    children =
      if datadog do
        # spandex datadog api server is able to flush when disabled?: true
        [{SpandexDatadog.ApiServer, spandex_datadog_options()}]
      else
        set_statix_global_tag()

        [
          {OMG.Status.Metric.StatsdMonitor, [alarm_module: Alarm, child_module: Datadog]},
          VmstatsSink.prepare_child(),
          {SpandexDatadog.ApiServer, spandex_datadog_options()}
        ]
      end

    # TODO remove when running full releases (it'll be covered with config providers)
    :ok = configure_sentry()
    Supervisor.start_link(children, strategy: :one_for_one, name: Status.Supervisor)
  end

  def start_phase(:install_alarm_handler, _start_type, _phase_args) do
    :ok = AlarmHandler.install()
  end

  defp configure_sentry do
    app_env = System.get_env("APP_ENV")
    sentry_dsn = System.get_env("SENTRY_DSN")

    case {is_binary(app_env), is_binary(sentry_dsn)} do
      {true, true} -> Application.put_env(:sentry, :included_environments, [app_env], persistent: true)
      _ -> Application.put_env(:sentry, :included_environments, [], persistent: true)
    end
  end

  @spec is_disabled?() :: boolean()
  defp is_disabled?() do
    case System.get_env("DD_DISABLED") do
      "false" -> false
      _ -> true
    end
  end

  defp spandex_datadog_options do
    env = System.get_env()
    config = Application.get_all_env(:spandex_datadog)
    config_host = env["DD_HOSTNAME"] || config[:host]
    config_port = env["DD_TRACING_PORT"] || config[:port]
    config_batch_size = env["TRACING_BATCH_SIZE"] || config[:batch_size]
    config_sync_threshold = env["TRACING_SYNC_THRESHOLD"] || config[:sync_threshold]
    config_http = env["TRACING_HTTP"] || config[:http]
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

  defp set_statix_global_tag do
    Application.put_env(:statix, :tags, ["application:#{get_application_mode()}"], persistent: true)
  end

  # TODO yet another hack because of lacking releases
  # we store the tag in the process dictionary so that we don't have to go through the
  # difficult path of retrieving it later
  defp get_application_mode do
    case Process.get(:application_mode) do
      nil ->
        application = application()
        nil = Process.put(:application_mode, application)
        application

      application ->
        application
    end
  end

  defp application do
    is_child_chain_running =
      Enum.find(Application.started_applications(), fn
        {:omg_child_chain_rpc, _, _} -> true
        _ -> false
      end)

    if Code.ensure_loaded?(OMG.ChildChainRPC) and is_child_chain_running != nil do
      :child_chain
    else
      :watcher
    end
  end
end
