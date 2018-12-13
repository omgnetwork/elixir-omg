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

defmodule Mix.Tasks.Xomg.ChildChain.Start do
  @moduledoc """
    Contains mix.task to run the child chain server
  """

  use Mix.Task

  @shortdoc "Start the child chain server. See Mix.Tasks.ChildChain"

  # TODO: a lot of this code is duplicated in other `Mix.Tasks` modules. How to DRY elegantly?
  def run(args) do
    args = ensure_contains(args, "--no-start")
    args = ensure_doesnt_contain(args, "--no-halt")

    Mix.Task.run("run", args)
    {:ok, _} = Application.ensure_all_started(:omg_api)
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
