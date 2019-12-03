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

defmodule OMG.WatcherInformational.ReleaseTasks.SetChildChainTest do
  use ExUnit.Case, async: false
  alias OMG.WatcherInformational.ReleaseTasks.SetChildChain

  @app :omg_watcher_informational
  @configuration_old Application.get_all_env(@app)

  setup do
    on_exit(fn ->
      # configuration is global state so we reset it to known values in case
      # it got fiddled before

      :ok =
        Enum.each(@configuration_old, fn {key, value} -> Application.put_env(@app, key, value, persistent: true) end)
    end)

    :ok
  end

  test "if environment variables get applied in the configuration" do
    # configuration is global state so we reset it to known values in case
    # it got fiddled before

    :ok = System.put_env("CHILD_CHAIN_URL", "/url/url")

    :ok = SetChildChain.init([])
    configuration = Enum.sort(Application.get_all_env(@app))
    "/url/url" = configuration[:child_chain_url]
    :ok = System.delete_env("CHILD_CHAIN_URL")

    ^configuration =
      @configuration_old
      |> Keyword.put(:child_chain_url, "/url/url")
      |> Enum.sort()
  end

  test "if default configuration is used when there's no environment variables" do
    :ok = System.delete_env("CHILD_CHAIN_URL")
    :ok = SetChildChain.init([])
    configuration = Application.get_all_env(@app)
    sorted_configuration = Enum.sort(configuration)
    ^sorted_configuration = Enum.sort(@configuration_old)
  end
end
