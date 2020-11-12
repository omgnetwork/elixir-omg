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

defmodule OMG.Status.Configuration do
  @moduledoc """
  Provides access to applications configuration
  """
  alias OMG.Status.Metric.Tracer

  @app :omg_status

  @spec system_memory_check_interval_ms() :: integer() | no_return()
  def system_memory_check_interval_ms() do
    Application.fetch_env!(@app, :system_memory_check_interval_ms)
  end

  @spec system_memory_high_threshold() :: float() | no_return()
  def system_memory_high_threshold() do
    Application.fetch_env!(@app, :system_memory_high_threshold)
  end

  @spec datadog_disabled?() :: boolean()
  def datadog_disabled?() do
    Application.fetch_env!(@app, Tracer)[:disabled?]
  end

  @spec release() :: atom() | nil
  def release() do
    Application.get_env(@app, :release)
  end

  @spec current_version() :: String.t() | nil
  def current_version() do
    Application.get_env(@app, :current_version)
  end
end
