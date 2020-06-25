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

defmodule OMG.ChildChain.ReleaseTasks.InitKeyValueDB do
  @moduledoc """
    Creates an empty instance of OMG DB storage for Child-chain application
  """

  require Logger
  @app :omg_db
  @start_apps [:logger, :crypto, :ssl]

  def run() do
    _ = on_load()

    result =
      @app
      |> Application.get_env(:path)
      |> process()

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
end
