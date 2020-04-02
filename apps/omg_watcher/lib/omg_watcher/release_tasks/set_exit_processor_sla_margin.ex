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

defmodule OMG.Watcher.ReleaseTasks.SetExitProcessorSLAMargin do
  @moduledoc false
  @behaviour Config.Provider
  require Logger
  @app :omg_watcher

  @system_env_name_margin "EXIT_PROCESSOR_SLA_MARGIN"
  @app_env_name_margin :exit_processor_sla_margin

  @system_env_name_force "EXIT_PROCESSOR_SLA_MARGIN_FORCED"
  @app_env_name_force :exit_processor_sla_margin_forced

  def init(args) do
    args
  end

  def load(config, _args) do
    _ = Application.ensure_all_started(:logger)

    Config.Reader.merge(config,
      omg_watcher: [
        exit_processor_sla_margin: get_exit_processor_sla_margin(),
        exit_processor_sla_margin_forced: get_exit_processor_sla_forced()
      ]
    )
  end

  defp get_exit_processor_sla_margin() do
    config_value = validate_int(get_env(@system_env_name_margin), Application.get_env(@app, @app_env_name_margin))
    _ = Logger.info("CONFIGURATION: App: #{@app} Key: #{@system_env_name_margin} Value: #{inspect(config_value)}.")
    config_value
  end

  defp get_exit_processor_sla_forced() do
    config_value = validate_bool(get_env(@system_env_name_force), Application.get_env(@app, @app_env_name_force))
    _ = Logger.info("CONFIGURATION: App: #{@app} Key: #{@system_env_name_force} Value: #{inspect(config_value)}.")
    config_value
  end

  defp get_env(key), do: System.get_env(key)

  defp validate_int(value, _default) when is_binary(value), do: to_int(value)
  defp validate_int(_, default), do: default

  defp validate_bool(value, _default) when is_binary(value), do: to_bool(String.upcase(value))
  defp validate_bool(_, default), do: default

  defp to_bool("TRUE"), do: true
  defp to_bool("FALSE"), do: false
  defp to_bool(_), do: exit("#{@system_env_name_force} either true or false.")

  defp to_int(value) do
    case Integer.parse(value) do
      {result, ""} -> result
      _ -> exit("#{@system_env_name_margin} must be an integer.")
    end
  end
end
