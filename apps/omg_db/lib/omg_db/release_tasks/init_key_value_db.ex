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

defmodule OMG.DB.ReleaseTasks.InitKeyValueDB do
  @moduledoc """
    Creates an empty instance of OMG DB storage and fills it with the required initial data.
  """

  @start_apps [:logger, :crypto, :ssl]
  require Logger

  def run do
    IO.inspect(Application.get_all_env(:omg_db))
    IO.inspect(Application.get_all_env(:omg_eth))
    IO.inspect(Application.get_all_env(:omg_childchain))
    IO.inspect(Application.get_all_env(:omg_omg))
    _ = Application.load(:omg_db)
    path = Application.get_env(:omg_db, :path)
    process(path)
  end

  defp process(path) do
    _ = Enum.each(@start_apps, &Application.ensure_all_started/1)
    _ = Logger.warn("Creating database at #{inspect(path)}")
    result = init_kv_db(path)
    Enum.each(Enum.reverse(@start_apps), &Application.stop/1)
    result
  end

  defp init_kv_db(path) do
    case OMG.DB.init(path) do
      {:error, term} ->
        _ = Logger.error("Could not initialize the DB in #{path}. Reason #{inspect(term)}")
        {:error, term}

      :ok ->
        _ = Logger.warn("The database at #{inspect(path)} has been created")
    end
  end
end
