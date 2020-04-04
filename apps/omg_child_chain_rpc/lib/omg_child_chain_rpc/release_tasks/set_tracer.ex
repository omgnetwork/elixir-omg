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

defmodule OMG.ChildChainRPC.ReleaseTasks.SetTracer do
  @moduledoc false
  @behaviour Config.Provider
  require Logger
  alias OMG.ChildChainRPC.Tracer

  @app :omg_child_chain_rpc

  def init(args) do
    args
  end

  def load(config, args) do
    _ = on_load()
    adapter = Keyword.get(args, :system_adapter, System)
    _ = Process.put(:system_adapter, adapter)
    dd_disabled = get_dd_disabled()

    tracer_config =
      @app
      |> Application.get_env(Tracer)
      |> Keyword.put(:disabled?, dd_disabled)

    tracer_config =
      case dd_disabled do
        false -> Keyword.put(tracer_config, :env, get_app_env())
        true -> Keyword.put(tracer_config, :env, "")
      end

    Config.Reader.merge(config,
      omg_child_chain_rpc: [{OMG.ChildChainRPC.Tracer, tracer_config}],
      spandex_phoenix: [tracer: OMG.ChildChainRPC.Tracer]
    )
  end

  defp get_dd_disabled() do
    disabled = Application.get_env(@app, OMG.ChildChainRPC.Tracer)[:disabled?]
    dd_disabled? = validate_bool(get_env("DD_DISABLED"), disabled)

    _ = Logger.info("CONFIGURATION: App: #{@app} Key: DD_DISABLED Value: #{inspect(dd_disabled?)}.")
    dd_disabled?
  end

  defp get_app_env() do
    env = validate_app_env(get_env("APP_ENV"))
    _ = Logger.info("CONFIGURATION: App: #{@app} Key: APP_ENV Value: #{inspect(env)}.")
    env
  end

  defp get_env(key) do
    Process.get(:system_adapter).get_env(key)
  end

  defp validate_bool(value, _default) when is_binary(value), do: to_bool(String.upcase(value))
  defp validate_bool(_, default), do: default

  defp to_bool("TRUE"), do: true
  defp to_bool("FALSE"), do: false
  defp to_bool(_), do: exit("DD_DISABLED either true or false.")

  defp validate_app_env(value) when is_binary(value), do: value
  defp validate_app_env(nil), do: exit("APP_ENV must be set.")

  defp on_load() do
    _ = Application.ensure_all_started(:logger)
    _ = Application.load(@app)
  end
end
