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

defmodule OMG.Status.ReleaseTasks.SetLoggerTest do
  use ExUnit.Case, async: true
  alias OMG.Status.ReleaseTasks.SetLogger
  @app :logger

  setup do
    :ok = System.delete_env("LOGGER_BACKEND")

    on_exit(fn ->
      :ok = System.delete_env("LOGGER_BACKEND")
    end)
  end

  test "if environment variables (INK) get applied in the configuration" do
    :ok = System.put_env("LOGGER_BACKEND", "INK")
    config = SetLogger.load([], [])
    backends = config |> Keyword.fetch!(:logger) |> Keyword.fetch!(:backends)
    assert Enum.member?(backends, Ink) == true
  end

  test "if environment variables (CONSOLE) get applied in the configuration" do
    # env var to console and asserting that Ink gets removed
    :ok = System.put_env("LOGGER_BACKEND", "conSole")
    config = SetLogger.load([], [])
    backends = config |> Keyword.fetch!(:logger) |> Keyword.fetch!(:backends)
    assert Enum.member?(backends, :console) == true
  end

  test "if environment variables are not present the default configuration gets used (INK)" do
    config = SetLogger.load([], [])
    backends = config |> Keyword.fetch!(@app) |> Keyword.fetch!(:backends)
    assert Enum.member?(backends, :console) == false
    assert Enum.member?(backends, Ink) == true
  end
end
