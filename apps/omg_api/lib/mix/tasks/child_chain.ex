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

defmodule Mix.Tasks.Omg.ChildChain do
  @moduledoc """
    Contains mix.task to run the child chain server
  """

  use Mix.Task

  @shortdoc "Start the child chain server. See Mix.Tasks.ChildChain"

  def run(args) do
    args = ensure_contains(args, "--no-start")
    no_halt = Enum.member?(args, "--no-halt")
    args = ensure_doesnt_contains(args, "--no-halt")

    Mix.Task.run("run", args)
    Application.ensure_all_started(:omg_api)
    if !no_halt, do: Process.sleep(:infinity)
  end

  defp ensure_contains(args, arg) do
    if !Enum.member?(args, arg) do
      [arg | args]
    else
      args
    end
  end

  defp ensure_doesnt_contains(args, arg) do
    List.delete(args, arg)
  end

end
