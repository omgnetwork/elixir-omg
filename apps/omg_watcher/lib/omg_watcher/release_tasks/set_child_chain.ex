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

defmodule OMG.Watcher.ReleaseTasks.SetChildChain do
  @moduledoc false
  @behaviour Config.Provider
  require Logger
  @app :omg_watcher

  def init(_args) do
    _ = Application.ensure_all_started(:logger)
    :ok = Application.put_env(@app, :child_chain_url, get_app_env(), persistent: true)
  end

  defp get_app_env() do
    child_chain_url = validate_string(get_env("CHILD_CHAIN_URL"), Application.get_env(@app, :child_chain_url))

    _ = Logger.info("CONFIGURATION: App: #{@app} Key: CHILD_CHAIN_URL Value: #{inspect(child_chain_url)}.")
    child_chain_url
  end

  defp get_env(key), do: System.get_env(key)

  defp validate_string(value, _default) when is_binary(value), do: value
  defp validate_string(_, default), do: default
end
