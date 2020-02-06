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

defmodule XomgTasks.Utils do
  @moduledoc """
  Common convenience code used to run Mix.Tasks goes here
  """

  @doc """
  Runs a specific app for some arguments. Will handle IEx, if one's running
  """
  def generic_run(args, apps) when is_list(apps) do
    Mix.Task.run("run", args)

    _ =
      Enum.each(apps, fn app ->
        {:ok, _} = Application.ensure_all_started(app)
      end)

    iex_running?() || Process.sleep(:infinity)
  end

  @doc """
  Will do all the generic preparations on the arguments required
  """
  def generic_prepare_args(args) do
    args
    |> ensure_contains("--no-start")
    |> ensure_doesnt_contain("--no-halt")
  end

  defp iex_running?() do
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
