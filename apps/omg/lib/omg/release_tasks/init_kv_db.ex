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

defmodule OMG.ReleaseTasks.InitKVDB do
  @moduledoc """
  A release task that performs database initialization.
  """
  use Mix.Releases.Config.Provider

  @start_apps [:logger, :crypto, :ssl]

  @impl Provider
  def init(_args) do
    path = get_env("DB_PATH")
    :ok = Application.put_env(:omg_db, :leveldb_path, path, persistent: true)
    process(path)
    :ok
  end

  defp process(path) do
    Enum.each(@start_apps, &Application.ensure_all_started/1)
    _ = init_kv_db(path)
    Enum.each(Enum.reverse(@start_apps), &Application.stop/1)
  end

  defp init_kv_db(path) do
    case OMG.DB.init(path) do
      {:error, term} -> exit("Could not init the DB in #{path}. Reason #{inspect(term)}")
      :ok -> :ok
    end
  end

  defp get_env(key), do: validate(System.get_env(key))

  defp validate(value) when is_binary(value), do: value

  defp validate(nil), do: exit("Set DB_PATH environment variable.")
end
