# Copyright 2019-2020 OMG Network Pte Ltd
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
  use ExUnit.Case, async: true

  alias OMG.Watcher.ReleaseTasks.SetExitProcessorSLAMargin
  @app :omg_watcher

  test "if environment variables get applied in the configuration" do
    :ok = System.put_env("EXIT_PROCESSOR_SLA_MARGIN", "15")
    :ok = System.put_env("EXIT_PROCESSOR_SLA_MARGIN_FORCED", "TRUE")
    config = SetExitProcessorSLAMargin.load([], [])
    exit_processor_sla_margin = config |> Keyword.fetch!(@app) |> Keyword.fetch!(:exit_processor_sla_margin)

    exit_processor_sla_margin_forced =
      config |> Keyword.fetch!(@app) |> Keyword.fetch!(:exit_processor_sla_margin_forced)

    assert exit_processor_sla_margin == 15
    assert exit_processor_sla_margin_forced == true
  end

  test "if default configuration is used when there's no environment variables" do
    :ok = System.delete_env("EXIT_PROCESSOR_SLA_MARGIN")
    :ok = System.delete_env("EXIT_PROCESSOR_SLA_MARGIN_FORCED")
    config = SetExitProcessorSLAMargin.load([], [])
    exit_processor_sla_margin = config |> Keyword.fetch!(@app) |> Keyword.fetch!(:exit_processor_sla_margin)

    exit_processor_sla_margin_forced =
      config |> Keyword.fetch!(@app) |> Keyword.fetch!(:exit_processor_sla_margin_forced)

    exit_processor_sla_margin_updated = Application.get_env(@app, :exit_processor_sla_margin)
    exit_processor_sla_margin_forced_updated = Application.get_env(@app, :exit_processor_sla_margin_forced)
    assert exit_processor_sla_margin == exit_processor_sla_margin_updated
    assert exit_processor_sla_margin_forced == exit_processor_sla_margin_forced_updated
  end

  test "if exit is thrown when faulty margin configuration is used" do
    :ok = System.put_env("EXIT_PROCESSOR_SLA_MARGIN", "15a")
    catch_exit(SetExitProcessorSLAMargin.load([], []))
    :ok = System.delete_env("EXIT_PROCESSOR_SLA_MARGIN")
  end

  test "if exit is thrown when faulty margin force configuration is used" do
    :ok = System.put_env("EXIT_PROCESSOR_SLA_MARGIN_FORCED", "15")
    catch_exit(SetExitProcessorSLAMargin.load([], []))
    :ok = System.delete_env("EXIT_PROCESSOR_SLA_MARGIN_FORCED")
  end
end
