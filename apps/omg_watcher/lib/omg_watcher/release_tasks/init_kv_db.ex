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

defmodule OMG.Watcher.ReleaseTasks.InitKVDB do
  @moduledoc """
  A release task that performs database initialization.
  """

  import IO.ANSI
  @start_apps [:logger, :crypto, :ssl]
  @apps [:omg_db]

  def run do
    Enum.each(@start_apps, &Application.ensure_all_started/1)
    Enum.each(@apps, &init_kv_db/1)
    :init.stop()
  end

  defp init_kv_db(app_name) do
    case OMG.DB.init() do
      {:error, term} -> error("The database for #{inspect(app_name)} couldn't be created: #{term}")
      :ok -> info("The database for #{inspect(app_name)} has been created")
    end
  end

  defp info(message), do: [:normal, message] |> format |> IO.puts()

  def error(message, device \\ :stderr) do
    formatted = format([:red, message])
    IO.puts(device, formatted)
  end
end
