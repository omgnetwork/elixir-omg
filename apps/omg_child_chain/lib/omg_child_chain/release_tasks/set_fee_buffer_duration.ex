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
  @behaviour Config.Provider
  require Logger

  @app :omg_child_chain
  @env_var_name "FEE_BUFFER_DURATION_MS"

  def init(args) do
    args
  end

  def load(config, _args) do
    _ = on_load()
    buffer_ms = fee_buffer_ms()
    Config.Reader.merge(config, omg_child_chain: [fee_buffer_duration_ms: buffer_ms])
  end

  defp fee_buffer_ms() do
    buffer_ms =
      @env_var_name
      |> System.get_env()
      |> validate_integer(Application.get_env(@app, :fee_buffer_duration_ms))

    _ = Logger.info("CONFIGURATION: App: #{@app} Key: fee_buffer_duration_ms Value: #{inspect(buffer_ms)}.")

    buffer_ms
  end

  defp validate_integer(value, _default) when is_binary(value), do: String.to_integer(value)
  defp validate_integer(_, default), do: default

  defp on_load() do
    _ = Application.ensure_all_started(:logger)
    _ = Application.load(@app)
  end
end
