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
  use ExUnit.Case, async: false
  alias OMG.Status.ReleaseTasks.SetLogger
  @app :logger
  setup_all do
    logger_backends = Application.get_env(@app, :backends, persistent: true)

    on_exit(fn ->
      :ok = Application.put_env(@app, :backends, logger_backends)
      :ok = System.delete_env("LOGGER_BACKEND")
    end)

    :ok
  end

  setup do
    :ok = System.delete_env("LOGGER_BACKEND")
  end

  test "if environment variables (INK) get applied in the configuration" do
    :ok = System.put_env("LOGGER_BACKEND", "INK")
    :ok = SetLogger.init([])
    configuration = Application.get_env(@app, :backends)
    assert Enum.member?(configuration, Ink) == true
  end

  test "if environment variables (CONSOLE) get applied in the configuration" do
    # env var to console and asserting that Ink gets removed
    :ok = System.put_env("LOGGER_BACKEND", "conSole")
    :ok = SetLogger.init([])
    configuration = Application.get_env(@app, :backends)
    assert Enum.member?(configuration, :console) == true
    assert Enum.member?(configuration, Ink) == false
  end

  test "if environment variables are not present the default configuration gets used (INK)" do
    # in mix_env == test the default logger is :console and Sentry.LoggerBackend
    # we want to test our production default setting which is Ink and Sentry.LoggerBackend
    # so we modify the configuration first so that it looks like in mix env prod
    Application.put_env(@app, :backends, [Ink, Sentry.LoggerBackend], persistent: true)
    # we continue with setting the backend to console and asserting that Ink gets removed
    :ok = SetLogger.init([])
    configuration = Application.get_env(@app, :backends)
    assert Enum.member?(configuration, :console) == false
    assert Enum.member?(configuration, Ink) == true
  end
end
