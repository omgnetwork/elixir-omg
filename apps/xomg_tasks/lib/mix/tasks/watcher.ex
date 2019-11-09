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

defmodule Mix.Tasks.Xomg.Watcher.Start do
  @moduledoc """
    Contains mix.task to run the watcher in different modes:
      a) mix xomg.watcher.start ----> security critical
      b) mix xomg.watcher.start --convenience ----> security critical + convenience api

    See the README.md file.
  """
  use Mix.Task

  import XomgTasks.Utils

  @shortdoc "Starts the watcher. See Mix.Tasks.Watcher for possible options"

  def run(["--convenience" | args]) do
    start_watcher(args)
  end

  def run(args) do
    start_watcher(args)
  end

  defp start_watcher(args) do
    args
    |> generic_prepare_args()
    |> generic_run([:omg_watcher, :omg_watcher_rpc])
  end
end
