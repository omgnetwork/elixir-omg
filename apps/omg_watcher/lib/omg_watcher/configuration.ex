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

defmodule OMG.Watcher.Configuration do
  @moduledoc """
  Provides access to applications configuration
  """
  @app :omg_watcher
  def exit_processor_sla_margin() do
    Application.fetch_env!(@app, :exit_processor_sla_margin)
  end

  def exit_processor_sla_margin_force() do
    Application.fetch_env!(@app, :exit_processor_sla_margin_force)
  end

  def metrics_collection_interval() do
    Application.fetch_env!(@app, :metrics_collection_interval)
  end
end
