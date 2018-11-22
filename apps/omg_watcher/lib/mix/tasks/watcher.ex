# Copyright 2018 OmiseGO Pte Ltd
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

defmodule Mix.Tasks.Omg.Watcher do
  @moduledoc """
    Contains mix.task to run the watcher in different modes:
      a) mix omg.watcher ----> security critical
      b) mix omg.watcher convenience ----> security critical + convenience api

    See the docs/TODO file.
  """
  use Mix.Task

  @shortdoc "Starts the watcher. See Mix.Tasks.Watcher for possible options"

  def run(["convenience"]) do
    Application.put_env(:omg_watcher, :convenience_api_mode, true, persistent: true)
    start_watcher()
  end

  def run(_) do
    start_watcher()
  end

  defp start_watcher do
    Mix.shell().cmd("cd apps/omg_watcher && iex -S mix run")
  end
end
