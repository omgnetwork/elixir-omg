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

defmodule OMG.ChildChain.ReleaseTasks.SetFeeFilePath do
  @moduledoc false
  use Distillery.Releases.Config.Provider
  require Logger

  @app :omg_child_chain
  @config_key :fee_specs_file_path
  @env_var_name "FEE_SPECS_FILE_PATH"

  @impl Provider
  def init(_args) do
    _ = Application.ensure_all_started(:logger)

    path =
      case get_env(@env_var_name) do
        root_path when is_binary(root_path) ->
          {:ok, path} = set_path(root_path)
          path

        _ ->
          Application.get_env(@app, @config_key)
      end

    _ = Logger.info("CONFIGURATION: App: #{@app} Key: #{@env_var_name} Value: #{inspect(path)}.")
    :ok
  end

  # sobelow_skip ["Traversal"]
  defp set_path(path) do
    :ok = Application.put_env(@app, @config_key, path, persistent: true)
    :ok = path |> Path.dirname() |> File.mkdir_p()
    :ok = File.write(path, "{}")

    {:ok, path}
  end

  defp get_env(key), do: System.get_env(key)
end
