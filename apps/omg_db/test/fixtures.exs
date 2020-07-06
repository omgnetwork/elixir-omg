# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule OMG.DB.Fixtures do
  @moduledoc """
  Contains fixtures for tests that require db
  """
  use ExUnitFixtures.FixtureModule

  deffixture db_initialized do
    db_path = Briefly.create!(directory: true)

    :ok = OMG.DB.init(db_path)

    {:ok, started_apps} = Application.ensure_all_started(:omg_db)

    on_exit(fn ->
      Application.put_env(:omg_db, :path, nil)

      started_apps
      |> Enum.reverse()
      |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end)

    :ok
  end

  deffixture db_initialize_multi(db_initialized) do
    :ok = db_initialized

    db_path = Application.fetch_env!(:omg_db, :path)
    instance = OMG.DB.Instance.ExitProcessor
    :ok = OMG.DB.init(db_path, [instance])

    {:ok, _} = OMG.DB.start_link(db_path: db_path, instance: instance)

    :ok
  end
end
