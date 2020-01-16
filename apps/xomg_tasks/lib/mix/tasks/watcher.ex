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

defmodule Mix.Tasks.Xomg.Watcher.Start do
  @moduledoc """
  Contains mix.task to run the watcher in security-critical only modes.

  See the README.md file.
  """
  use Mix.Task

  import XomgTasks.Utils

  @shortdoc "Starts the security-critical watcher. See Mix.Tasks.Watcher."

  def run(args) do
    args
    |> generic_prepare_args()
    |> generic_run([:omg_watcher, :omg_watcher_rpc])
  end
end
