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

defmodule OMG.ChildChain.Configuration do
  @moduledoc """
  Interface for accessing all Child Chain configuration
  """
  @spec metrics_collection_interval() :: no_return | pos_integer()
  def metrics_collection_interval() do
    Application.fetch_env!(:omg_child_chain, :metrics_collection_interval)
  end

  @spec block_queue_eth_height_check_interval_ms() :: no_return | pos_integer()
  def block_queue_eth_height_check_interval_ms() do
    Application.fetch_env!(:omg_child_chain, :block_queue_eth_height_check_interval_ms)
  end

  @spec submission_finality_margin() :: no_return | pos_integer()
  def submission_finality_margin() do
    Application.fetch_env!(:omg_child_chain, :submission_finality_margin)
  end

  @spec block_submit_every_nth() :: no_return | pos_integer()
  def block_submit_every_nth() do
    Application.fetch_env!(:omg_child_chain, :block_submit_every_nth)
  end
end
