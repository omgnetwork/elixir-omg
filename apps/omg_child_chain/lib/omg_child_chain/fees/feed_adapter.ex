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

defmodule OMG.ChildChain.Fees.FeedAdapter do
  @moduledoc """
  Adapter pulls actual fees prices from fee feed.
  """
  @behaviour OMG.ChildChain.Fees.Adapter

  use OMG.Utils.LoggerExt

  # alias OMG.ChildChain.Fees.FeeParser

  @doc """
  Pulls the fee specification from fees feed. Feed updates fee prices based on Ethereum's gas price.
  """
  # sobelow_skip ["Traversal"]
  @impl true
  def get_fee_specs(_actual_fee_specs, _updated_at) do
    opts = Application.fetch_env!(:omg_child_chain, :fee_adapter_opts)
    _feed_url = Keyword.fetch!(opts, :feed_url)
    _stored_fee_update_interval_minutes = Keyword.fetch!(opts, :stored_fee_update_interval_minutes)
    _fee_change_tolerance_percent = Keyword.fetch!(opts, :fee_change_tolerance_percent)
  end
end
