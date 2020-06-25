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

defmodule OMG.Watcher.ReleaseTasks.InitKeyValueDB do
  @moduledoc """
    Creates an empty instance of OMG DB storage and fills it with the required initial data.
  """

  @app :omg_db
  @default_db_folder "app"
  @start_apps [:logger, :crypto, :ssl]

  require Logger

  def run_multi() do
    _ = on_load()

    root_path =
      @app
      |> Application.get_env(:path)
      |> OMG.DB.root_path()

    result =
      ["exit_processor", @default_db_folder]
      |> Enum.map(&Path.join([root_path, &1]))
      |> Enum.map(&process/1)
      |> all_ok_or_error()

    _ = on_done()
    result
  end

  defp process(path) do
    _ = Logger.warn("Creating database at #{inspect(path)}")

    case OMG.DB.init(path) do
      {:error, term} ->
        _ = Logger.error("Could not initialize the DB in #{path}. Reason #{inspect(term)}")
        {:error, term}

      :ok ->
        _ = Logger.warn("The database at #{inspect(path)} has been created")
    end
  end

  defp on_load() do
    _ = Enum.each(@start_apps, &Application.ensure_all_started/1)
    _ = Application.load(@app)
  end

  defp on_done() do
    _ = Enum.each(Enum.reverse(@start_apps), &Application.stop/1)
  end

  defp all_ok_or_error([]), do: :ok
  defp all_ok_or_error([:ok | rest]), do: all_ok_or_error(rest)
  defp all_ok_or_error([error | _]), do: error
end
