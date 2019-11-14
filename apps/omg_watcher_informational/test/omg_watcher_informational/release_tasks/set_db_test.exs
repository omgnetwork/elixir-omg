# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.WatcherInformational.ReleaseTasks.SetDBTest do
  use ExUnit.Case, async: false
  alias OMG.WatcherInformational.DB.Repo
  alias OMG.WatcherInformational.ReleaseTasks.SetDB

  @app :omg_watcher_informational
  @configuration_old Application.get_env(@app, Repo)

  setup do
    on_exit(fn ->
      # configuration is global state so we reset it to known values in case
      # it got fiddled before

      :ok = Application.put_env(@app, Repo, @configuration_old, persistent: true)
    end)

    :ok
  end

  test "if environment variables get applied in the configuration" do
    :ok = System.put_env("DATABASE_URL", "/url/url")

    :ok = SetDB.init([])
    configuration = Application.get_env(@app, Repo)
    "/url/url" = configuration[:url]

    ^configuration =
      @configuration_old
      |> Keyword.put(:url, "/url/url")

    :ok = System.delete_env("DATABASE_URL")
  end

  test "if default configuration is used when there's no environment variables" do
    :ok = System.delete_env("DATABASE_URL")
    :ok = SetDB.init([])
    configuration = Application.get_env(@app, Repo)
    sorted_configuration = Enum.sort(configuration)
    ^sorted_configuration = Enum.sort(@configuration_old)
  end
end
