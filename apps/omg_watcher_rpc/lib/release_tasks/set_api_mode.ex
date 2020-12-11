# Copyright 2019-2019 OMG Network Pte Ltd
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

defmodule OMG.WatcherRPC.ReleaseTasks.SetApiMode do
  @moduledoc false
  @behaviour Config.Provider
  require Logger

  def init(nil) do
    exit("WatcherRPC's API mode is not provided.")
  end

  def init(args) do
    args
  end

  def load(config, api_mode) do
    Config.Reader.merge(config, omg_watcher_rpc: [api_mode: api_mode])
  end
end
