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

defmodule OMG.Watcher.ReleaseTasks.SetApplication do
  @moduledoc false
  @behaviour Config.Provider
  @app :omg_watcher

  def init(args) do
    args
  end

  def load(_config, release: release, current_version: current_version) do
    :ok = Application.put_env(@app, :release, release, persistent: true)
    :ok = Application.put_env(@app, :current_version, current_version, persistent: true)
  end
end
