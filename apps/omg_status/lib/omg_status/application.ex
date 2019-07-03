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
  #  alias Status.Metric.Recorder
  alias OMG.Status.Alert.AlarmHandler
  alias OMG.Status.Metric.Datadog

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    :ok = DeferredConfig.populate(:statix)
    :ok = DeferredConfig.populate(:omg_status)

    if is_enabled?() do
      _ = Application.put_env(:vmstats, :sink, Status.Metric.Recorder)
    end

    spandex = [
      {SpandexDatadog.ApiServer,
       [
         host: System.get_env("DATADOG_HOST") || "localhost",
         port: System.get_env("DATADOG_PORT") || 8126,
         batch_size: System.get_env("SPANDEX_BATCH_SIZE") || 10,
         sync_threshold: System.get_env("SPANDEX_SYNC_THRESHOLD") || 100,
         http: HTTPoison
       ]}
    ]

    # TODO remove when running full releases (it'll be covered with config providers)
    :ok = configure_sentry()
    :ok = Datadog.connect()
    Supervisor.start_link(spandex, strategy: :one_for_one, name: Status.Supervisor)
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
