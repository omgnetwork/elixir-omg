# Copyright 2019-2019 OMG Network Pte Ltd
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

defmodule OMG.Status.ReleaseTasks.SetLogger do
  @moduledoc false
  @behaviour Config.Provider
  require Logger

  @app :logger
  @default_backend Ink

  def init(args) do
    args
  end

  def load(config, _args) do
    _ = on_load()
    logger_backends = Application.get_env(@app, :backends, persistent: true)
    logger_backend = get_logger_backend()

    remove =
      case logger_backend do
        :console -> Ink
        _ -> :console
      end

    backends = logger_backends |> Kernel.--([remove]) |> Enum.concat([logger_backend]) |> Enum.uniq()
    Config.Reader.merge(config, logger: [backends: backends])
  end

  defp get_logger_backend() do
    logger =
      "LOGGER_BACKEND"
      |> get_env()
      |> validate_string(@default_backend)

    _ = Logger.info("CONFIGURATION: App: #{@app} Key: LOGGER_BACKEND Value: #{inspect(logger)}.")
    logger
  end

  defp get_env(key), do: System.get_env(key)

  defp validate_string(nil, default), do: default
  defp validate_string(value, default), do: do_validate_string(String.upcase(value), default)
  defp do_validate_string("CONSOLE", _default), do: :console
  defp do_validate_string("INK", _default), do: Ink
  defp do_validate_string(_, default), do: default

  defp on_load() do
    _ = Application.load(:logger)
  end
end
