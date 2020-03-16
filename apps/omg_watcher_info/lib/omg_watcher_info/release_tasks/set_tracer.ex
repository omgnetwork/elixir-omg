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

defmodule OMG.WatcherInfo.ReleaseTasks.SetTracer do
  @moduledoc false
  use Distillery.Releases.Config.Provider
  require Logger
  @app :omg_watcher_info

  @impl Provider
  def init(_args) do
    _ = Application.ensure_all_started(:logger)
    config = Application.get_env(@app, OMG.WatcherInfo.Tracer)
    config = Keyword.put(config, :disabled?, get_dd_disabled())
    config = Keyword.put(config, :env, get_app_env())

    :ok = Application.put_env(@app, OMG.WatcherInfo.Tracer, config, persistent: true)
  end

  defp get_dd_disabled() do
    dd_disabled? = validate_bool(get_env("DD_DISABLED"), Application.get_env(@app, OMG.WatcherInfo.Tracer)[:disabled?])

    _ = Logger.info("CONFIGURATION: App: #{@app} Key: DD_DISABLED Value: #{inspect(dd_disabled?)}.")
    dd_disabled?
  end

  defp get_app_env() do
    env = validate_app_env(get_env("APP_ENV"))
    _ = Logger.info("CONFIGURATION: App: #{@app} Key: APP_ENV Value: #{inspect(env)}.")
    env
  end

  defp get_env(key), do: System.get_env(key)

  defp validate_bool(value, _default) when is_binary(value), do: to_bool(String.upcase(value))
  defp validate_bool(_, default), do: default

  defp to_bool("TRUE"), do: true
  defp to_bool("FALSE"), do: false
  defp to_bool(_), do: exit("DD_DISABLED either true or false.")

  defp validate_app_env(value) when is_binary(value), do: value
  defp validate_app_env(nil), do: exit("APP_ENV must be set.")
end
