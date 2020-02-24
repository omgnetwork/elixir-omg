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

defmodule OMG.ChildChain.ReleaseTasks.SetFeeBufferDuration do
  @moduledoc false
  use Distillery.Releases.Config.Provider
  require Logger

  @app :omg_child_chain
  @config_key :fee_buffer_duration_ms
  @env_name "FEE_BUFFER_DURATION_MS"

  @impl Provider
  def init(_args) do
    _ = Application.ensure_all_started(:logger)
    buffer_ms = fee_buffer_ms()

    :ok = Application.put_env(@app, @config_key, buffer_ms, persistent: true)
  end

  defp fee_buffer_ms() do
    buffer_ms =
      @env_name
      |> System.get_env()
      |> validate_integer(Application.get_env(@app, @config_key))

    _ = Logger.info("CONFIGURATION: App: #{@app} Key: #{@config_key} Value: #{inspect(buffer_ms)}.")

    buffer_ms
  end

  defp get_env(key), do: System.get_env(key)

  defp validate_integer(value, _default) when is_binary(value), do: String.to_integer(value)
  defp validate_integer(_, default), do: default
end
