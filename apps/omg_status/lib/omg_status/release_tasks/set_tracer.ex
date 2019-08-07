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
  use Distillery.Releases.Config.Provider
  require Logger
  @app :omg_status

  @impl Provider
  def init(_args) do
    _ = Application.ensure_all_started(:logger)
    config = Application.get_env(:omg_status, OMG.Status.Metric.Tracer)
    config = Keyword.put(config, :disabled?, get_dd_disabled())
    config = Keyword.put(config, :env, get_app_env())
    :ok = Application.put_env(:omg_status, OMG.Status.Metric.Tracer, config, persistent: true)

    # statix setup
    :ok = Application.put_env(:statix, :host, get_dd_hostname(Application.get_env(:statix, :host)), persistent: true)
    :ok = Application.put_env(:statix, :port, get_dd_port(Application.get_env(:statix, :host)), persistent: true)
    # spandex_datadog setup

    :ok =
      Application.put_env(:spandex_datadog, :host, get_dd_hostname(Application.get_env(:spandex_datadog, :host)),
        persistent: true
      )

    :ok =
      Application.put_env(:spandex_datadog, :port, get_dd_port(Application.get_env(:spandex_datadog, :port)),
        persistent: true
      )

    :ok = Application.put_env(:spandex_datadog, :batch_size, get_batch_size(), persistent: true)
    :ok = Application.put_env(:spandex_datadog, :sync_threshold, get_sync_threshold(), persistent: true)
  end

  defp get_dd_disabled do
    dd_disabled? =
      validate_bool(
        get_env("DD_DISABLED"),
        Application.get_env(:omg_status, OMG.Status.Metric.Tracer)[:disabled?]
      )

    _ = Logger.warn("CONFIGURATION: App: #{@app} Key: DD_DISABLED Value: #{inspect(dd_disabled?)}.")
    dd_disabled?
  end

  defp get_app_env do
    env = validate_string(get_env("APP_ENV"), Application.get_env(@app, OMG.Status.Tracer)[:env])
    _ = Logger.warn("CONFIGURATION: App: #{@app} Key: APP_ENV Value: #{inspect(env)}.")
    env
  end

  defp get_dd_hostname(default) do
    dd_hostname = validate_string(get_env("DD_HOSTNAME"), default)
    _ = Logger.warn("CONFIGURATION: App: #{@app} Key: DD_HOSTNAME Value: #{inspect(dd_hostname)}.")
    dd_hostname
  end

  defp get_dd_port(default) do
    dd_hostname = validate_integer(get_env("DD_PORT"), default)
    _ = Logger.warn("CONFIGURATION: App: #{@app} Key: DD_PORT Value: #{inspect(dd_hostname)}.")
    dd_hostname
  end

  def get_batch_size do
    batch_size = validate_integer(get_env("BATCH_SIZE"), Application.get_env(:spandex_datadog, :batch_size))

    _ = Logger.warn("CONFIGURATION: App: #{@app} Key: BATCH_SIZE Value: #{inspect(batch_size)}.")
    batch_size
  end

  def get_sync_threshold do
    sync_threshold =
      validate_integer(
        get_env("SYNC_THRESHOLD"),
        Application.get_env(:spandex_datadog, :sync_threshold)
      )

    _ = Logger.warn("CONFIGURATION: App: #{@app} Key: SYNC_TRESHOLD Value: #{inspect(sync_threshold)}.")
    sync_threshold
  end

  defp get_env(key), do: System.get_env(key)

  defp validate_bool(value, default) when is_binary(value), do: to_bool(String.upcase(value), default)
  defp validate_bool(_, default), do: default

  defp to_bool("TRUE", _default), do: true
  defp to_bool("FALSE", _default), do: false
  defp to_bool(_, default), do: default

  defp validate_string(value, _default) when is_binary(value), do: value
  defp validate_string(_, default), do: default

  defp validate_integer(value, _default) when is_binary(value), do: String.to_integer(value)
  defp validate_integer(_, default), do: default
end
