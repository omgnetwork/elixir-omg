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

defmodule OMG.Eth.Configuration do
  @moduledoc """
  Provides access to applications configuration
  """
  @app :omg_eth
  def contract_semver() do
    Application.get_env(@app, :contract_semver)
  end

  def network() do
    Application.get_env(@app, :network)
  end

  @spec min_exit_period_seconds() :: no_return | pos_integer()
  def min_exit_period_seconds() do
    Application.fetch_env!(@app, :min_exit_period_seconds)
  end

  @spec ethereum_block_time_seconds() :: no_return | pos_integer()
  def ethereum_block_time_seconds() do
    Application.fetch_env!(@app, :ethereum_block_time_seconds)
  end

  @spec contracts() :: no_return | map()
  def contracts() do
    Application.fetch_env!(@app, :contract_addr)
  end

  @spec txhash_contract() :: no_return | binary()
  def txhash_contract(), do: Application.fetch_env!(:omg_eth, :txhash_contract)

  @spec authority_addr() :: no_return | binary()
  def authority_addr(), do: Application.fetch_env!(:omg_eth, :authority_addr)

  @spec environment() :: :test | nil
  def environment() do
    Application.get_env(@app, :environment)
  end
end
