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

defmodule OMG.Watcher.ReleaseTasks.SetExitProcessorSLAMarginTest do
  use ExUnit.Case, async: false

  alias OMG.Watcher.ReleaseTasks.SetExitProcessorSLAMargin
  @app :omg_watcher
  @configuration_old Application.get_env(@app, :exit_processor_sla_margin)

  setup do
    on_exit(fn ->
      # configuration is global state so we reset it to known values in case
      # it got fiddled before
      :ok = Application.put_env(@app, :exit_processor_sla_margin, @configuration_old, persistent: true)
    end)

    :ok
  end

  test "if environment variables get applied in the configuration" do
    :ok = System.put_env("EXIT_PROCESSOR_SLA_MARGIN", "15")
    :ok = SetExitProcessorSLAMargin.init([])
    exit_processor_sla_margin_updated = Application.get_env(@app, :exit_processor_sla_margin)

    assert 15 = exit_processor_sla_margin_updated
  end

  test "if default configuration is used when there's no environment variables" do
    :ok = System.delete_env("EXIT_PROCESSOR_SLA_MARGIN")
    :ok = SetExitProcessorSLAMargin.init([])

    assert @configuration_old = Application.get_env(@app, :exit_processor_sla_margin)
  end

  test "if exit is thrown when faulty configuration is used" do
    :ok = System.put_env("EXIT_PROCESSOR_SLA_MARGIN", "15a")
    catch_exit(SetExitProcessorSLAMargin.init([]))
    :ok = System.delete_env("EXIT_PROCESSOR_SLA_MARGIN")
  end
end
