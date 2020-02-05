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

defmodule OMG.ChildChain.ReleaseTasks.SetIgnoreFees do
  @moduledoc false
  use Distillery.Releases.Config.Provider
  require Logger

  @app :omg_child_chain
  @config_key :ignore_fees
  @env_name "IGNORE_FEES"

  @impl Provider
  def init(_args) do
    _ = Application.ensure_all_started(:logger)
    ignore_fees = ignore_fees()

    :ok = Application.put_env(@app, @config_key, interval_ms, persistent: true)
  end

  defp ignore_fees() do
    ignore_fees =
      validate_boolean(
        get_env(@env_name),
        Application.get_env(@app, @config_key)
      )

    _ = Logger.info("CONFIGURATION: App: #{@app} Key: #{@config_key} Value: #{inspect(ignore_fees)}.")

    ignore_fees
  end

  defp get_env(key), do: System.get_env(key)

  defp validate_boolean("true", _default), do: true
  defp validate_boolean("false", _default), do: false
  defp validate_boolean(nil, default), do: default
  defp validate_boolean(_, _default), do: exit("#{@env_name} can only be \"true\" or \"false\" or unset.")
end
