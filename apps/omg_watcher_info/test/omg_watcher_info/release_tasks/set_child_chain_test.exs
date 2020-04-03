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

defmodule OMG.WatcherInfo.ReleaseTasks.SetChildChainTest do
  use ExUnit.Case, async: true
  alias OMG.WatcherInfo.ReleaseTasks.SetChildChain

  @app :omg_watcher_info

  test "if environment variables get applied in the configuration" do
    :ok = System.put_env("CHILD_CHAIN_URL", "/url/url")
    config = SetChildChain.load([], [])
    config_child_chain_url = config |> Keyword.fetch!(@app) |> Keyword.fetch!(:child_chain_url)
    assert config_child_chain_url == "/url/url"
  end

  test "if default configuration is used when there's no environment variables" do
    :ok = System.delete_env("CHILD_CHAIN_URL")
    config = SetChildChain.load([], [])
    config_child_chain_url = config |> Keyword.fetch!(@app) |> Keyword.fetch!(:child_chain_url)
    child_chain_url = Application.get_env(@app, :child_chain_url)
    assert child_chain_url == config_child_chain_url
  end
end
