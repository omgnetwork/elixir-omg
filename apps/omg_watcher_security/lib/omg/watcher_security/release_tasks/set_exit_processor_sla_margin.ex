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

defmodule OMG.WatcherSecurity.ReleaseTasks.SetExitProcessorSLAMargin do
  @moduledoc false
  use Distillery.Releases.Config.Provider
  require Logger
  @app :omg_watcher_security

  @impl Provider

  @system_env_name "EXIT_PROCESSOR_SLA_MARGIN"
  @app_env_name :exit_processor_sla_margin

  def init(_args) do
    _ = Application.ensure_all_started(:logger)
    :ok = Application.put_env(@app, @app_env_name, get_exit_processor_sla_margin(), persistent: true)
  end

  defp get_exit_processor_sla_margin do
    config_value = validate_int(get_env(@system_env_name), Application.get_env(@app, @app_env_name))
    _ = Logger.info("CONFIGURATION: App: #{@app} Key: #{@system_env_name} Value: #{inspect(config_value)}.")
    config_value
  end

  defp get_env(key), do: System.get_env(key)

  defp validate_int(value, _default) when is_binary(value), do: to_int(value)
  defp validate_int(_, default), do: default

  defp to_int(value) do
    case Integer.parse(value) do
      {result, ""} -> result
      _ -> exit("#{@system_env_name} must be an integer.")
    end
  end
end
