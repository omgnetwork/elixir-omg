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
  @start_apps [:logger, :crypto, :ssl]

  require Logger

  def run_multi() do
    _ = on_load()

    base_path = Application.fetch_env!(@app, :path)
    instances = [OMG.DB.Instance.ExitProcessor]
    _ = Logger.warn("Creating database at #{inspect(base_path)} with instances #{inspect(instances)}")

    result = OMG.DB.init(base_path, instances)

    _ = on_done()
    result
  end

  defp on_load() do
    _ = Enum.each(@start_apps, &Application.ensure_all_started/1)
    _ = Application.load(@app)
  end

  defp on_done() do
    _ = Enum.each(Enum.reverse(@start_apps), &Application.stop/1)
  end
end
