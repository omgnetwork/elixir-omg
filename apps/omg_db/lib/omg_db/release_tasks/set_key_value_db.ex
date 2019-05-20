# Copyright 2018-2019 OmiseGO Pte Ltd
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

defmodule OMG.DB.ReleaseTasks.SetKeyValueDB do
  @moduledoc """
  Gets the DB path from environment and perstists it to configuration.
  """
  use Mix.Releases.Config.Provider

  @impl Provider
  def init(_args) do
    path = get_env("DB_PATH")
    :ok = Application.put_env(:omg_db, :path, path, persistent: true)
  end

  defp get_env(key), do: validate(System.get_env(key))

  defp validate(value) when is_binary(value), do: value

  defp validate(nil), do: exit("Set DB_PATH environment variable.")
end
