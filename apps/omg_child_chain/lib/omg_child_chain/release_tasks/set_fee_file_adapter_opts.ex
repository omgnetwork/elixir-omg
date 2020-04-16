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

defmodule OMG.ChildChain.ReleaseTasks.SetFeeFileAdapterOpts do
  @moduledoc """
  Detects if `FEE_ADAPTER` is set to `"FILE"` (case-insensitive). If so, it sets the system's
  fee adapter to FileAdapter and configures it with values from related environment variables.
  """
  @behaviour Config.Provider
  require Logger

  @app :omg_child_chain
  @config_key :fee_adapter
  @env_fee_adapter "FEE_ADAPTER"
  @env_fee_specs_file_path "FEE_SPECS_FILE_PATH"

  def init(args) do
    args
  end

  def load(config, _args) do
    _ = on_load()

    @env_fee_adapter
    |> System.get_env()
    |> parse_adapter_value()
    |> case do
      "FILE" -> configure_file_adapter(config)
      _ -> config
    end
  end

  defp parse_adapter_value(nil), do: :skip
  defp parse_adapter_value(value), do: String.upcase(value)

  defp configure_file_adapter(config) do
    specs_file_path = System.get_env(@env_fee_specs_file_path)

    adapter = {OMG.ChildChain.Fees.FileAdapter, opts: [specs_file_path: specs_file_path]}
    _ = Logger.info("CONFIGURATION: App: #{@app} Key: #{@config_key} Value: #{inspect(adapter)}.")

    Config.Reader.merge(config, omg_child_chain: [fee_adapter: adapter])
  end

  defp on_load() do
    _ = Application.ensure_all_started(:logger)
  end
end
