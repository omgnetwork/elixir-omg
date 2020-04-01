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

defmodule OMG.Configuration do
  @moduledoc """
  Provides access to applications configuration
  """
  @app :omg
  @spec deposit_finality_margin() :: pos_integer() | no_return
  def deposit_finality_margin() do
    Application.get_env(@app, :deposit_finality_margin)
  end

  @spec fee_claimer_address() :: binary() | no_return
  def fee_claimer_address() do
    Application.fetch_env!(@app, :fee_claimer_address)
  end

  @spec ethereum_events_check_interval_ms() :: pos_integer() | no_return
  def ethereum_events_check_interval_ms() do
    Application.fetch_env!(@app, :ethereum_events_check_interval_ms)
  end

  @spec coordinator_eth_height_check_interval_ms() :: pos_integer() | no_return
  def coordinator_eth_height_check_interval_ms() do
    Application.fetch_env!(@app, :coordinator_eth_height_check_interval_ms)
  end
end
