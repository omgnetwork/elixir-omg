# Copyright 2019-2019 OmiseGO Pte Ltd
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

defmodule OMG.Status.ReleaseTasks.SetTracer do
  @moduledoc false
  @behaviour Config.Provider
  alias OMG.Status.Metric.Tracer
  require Logger
  @app :omg_status

  def init(args) do
    args
  end

  def load(config, args) do
    _ = on_load()
    adapter = Keyword.get(args, :system_adapter, System)
    nil = Process.put(:system_adapter, adapter)
    dd_disabled = get_dd_disabled()

    tracer_config =
      @app
      |> Application.get_env(Tracer)
      |> Keyword.put(:disabled?, dd_disabled)

    tracer_config =
      case dd_disabled do
        false -> Keyword.put(tracer_config, :env, get_app_env())
        true -> Keyword.put(tracer_config, :env, "")
      end

    release = Keyword.get(args, :release)
    tags = ["application:#{release}", "app_env:#{get_app_env()}", "hostname:#{get_hostname()}"]
    spandex_datadog_host = Application.get_env(:spandex_datadog, :host)
    spandex_datadog_port = Application.get_env(:spandex_datadog, :port)
    statix_default_port = Application.get_env(:statix, :port)
    statix_default_hostname = Application.get_env(:statix, :host)

    Config.Reader.merge(config,
      spandex_datadog: [
        host: get_dd_hostname(spandex_datadog_host),
        port: get_dd_spandex_port(spandex_datadog_port),
        batch_size: get_batch_size(),
        sync_threshold: get_sync_threshold()
      ],
      statix: [
        port: get_dd_port(statix_default_port),
        host: get_dd_hostname(statix_default_hostname),
        tags: tags
      ],
      omg_status: [{Tracer, tracer_config}]
    )
  end

  defp get_hostname() do
    hostname = validate_hostname(get_env("HOSTNAME"))

    _ = Logger.info("CONFIGURATION: App: #{@app} Key: HOSTNAME Value: #{inspect(hostname)}.")
    hostname
  end

  defp get_dd_disabled() do
    dd_disabled? = validate_bool(get_env("DD_DISABLED"), Application.get_env(@app, Tracer)[:disabled?])

    _ = Logger.info("CONFIGURATION: App: #{@app} Key: DD_DISABLED Value: #{inspect(dd_disabled?)}.")
    dd_disabled?
  end

  defp get_app_env() do
    env = validate_string(get_env("APP_ENV"), Application.get_env(@app, Tracer)[:env])
    _ = Logger.info("CONFIGURATION: App: #{@app} Key: APP_ENV Value: #{inspect(env)}.")
    env
  end

  defp get_dd_hostname(default) do
    dd_hostname = validate_string(get_env("DD_HOSTNAME"), default)
    _ = Logger.info("CONFIGURATION: App: #{@app} Key: DD_HOSTNAME Value: #{inspect(dd_hostname)}.")
    dd_hostname
  end

  defp get_dd_port(default) do
    dd_port = validate_integer(get_env("DD_PORT"), default)
    _ = Logger.info("CONFIGURATION: App: #{@app} Key: DD_PORT Value: #{inspect(dd_port)}.")
    dd_port
  end

  defp get_dd_spandex_port(default) do
    dd_spandex_port = validate_integer(get_env("DD_APM_PORT"), default)
    _ = Logger.info("CONFIGURATION: App: #{@app} Key: DD_APM_PORT Value: #{inspect(dd_spandex_port)}.")
    dd_spandex_port
  end

  def get_batch_size() do
    batch_size = validate_integer(get_env("BATCH_SIZE"), Application.get_env(:spandex_datadog, :batch_size))

    _ = Logger.info("CONFIGURATION: App: #{@app} Key: BATCH_SIZE Value: #{inspect(batch_size)}.")
    batch_size
  end

  defp validate_hostname(value) when is_binary(value), do: value
  defp validate_hostname(_), do: exit("HOSTNAME is not set correctly.")

  def get_sync_threshold() do
    sync_threshold = Application.get_env(:spandex_datadog, :sync_threshold)
    sync_threshold = validate_integer(get_env("SYNC_THRESHOLD"), sync_threshold)

    _ = Logger.info("CONFIGURATION: App: #{@app} Key: SYNC_THRESHOLD Value: #{inspect(sync_threshold)}.")
    sync_threshold
  end

  defp get_env(key) do
    Process.get(:system_adapter).get_env(key)
  end

  defp validate_bool(value, _default) when is_binary(value), do: to_bool(String.upcase(value))
  defp validate_bool(_, default), do: default

  defp to_bool("TRUE"), do: true
  defp to_bool("FALSE"), do: false
  defp to_bool(_), do: exit("DD_DISABLED either true or false.")

  defp validate_string(value, _default) when is_binary(value), do: value
  defp validate_string(_, default), do: default

  defp validate_integer(value, _default) when is_binary(value), do: String.to_integer(value)
  defp validate_integer(_, default), do: default

  defp on_load() do
    _ = Application.ensure_all_started(:logger)
    _ = Application.load(@app)
    _ = Application.load(:spandex_datadog)
    _ = Application.load(:statix)
  end
end
