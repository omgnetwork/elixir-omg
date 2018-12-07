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

defmodule Mix.Tasks.Xomg.Watcher.Start do
  @moduledoc """
    Contains mix.task to run the watcher in different modes:
      a) mix xomg.watcher.start ----> security critical
      b) mix xomg.watcher.start --convenience ----> security critical + convenience api

    See the docs/TODO file.
  """
  use Mix.Task

  @shortdoc "Starts the watcher. See Mix.Tasks.Watcher for possible options"

  def run(["--convenience" | args]) do
    Application.put_env(:omg_watcher, :convenience_api_mode, true, persistent: true)
    start_watcher(args)
  end

  def run(args) do
    start_watcher(args)
  end

  # TODO: a lot of this code is duplicated in other `Mix.Tasks` modules. How to DRY elegantly?
  defp start_watcher(args) do
    args = ensure_contains(args, "--no-start")
    args = ensure_doesnt_contain(args, "--no-halt")

    Mix.Task.run("run", args)
    {:ok, _} = Application.ensure_all_started(:omg_watcher)
    iex_running?() || Process.sleep(:infinity)
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) and IEx.started?()
  end

  defp ensure_contains(args, arg) do
    if Enum.member?(args, arg) do
      args
    else
      [arg | args]
    end
  end

  defp ensure_doesnt_contain(args, arg) do
    List.delete(args, arg)
  end
end
