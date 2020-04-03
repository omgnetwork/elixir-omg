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

defmodule OMG.ChildChain.CoordinatorSetup do
  @moduledoc """
   The setup of `OMG.RootChainCoordinator` for the child chain server - configures the relations between different
   event listeners
  """

  @doc """
  The `OMG.RootChainCoordinator` setup for the `OMG.ChildChain` app. Summary of the configuration:

    - deposits are recognized after `deposit_finality_margin`
    - exit-related events don't have any finality margin, but wait for deposits
    - piggyback-related events must wait for IFE start events
  """

  def coordinator_setup(metrics_collection_interval, coordinator_eth_height_check_interval_ms, deposit_finality_margin) do
    {[
       metrics_collection_interval: metrics_collection_interval,
       coordinator_eth_height_check_interval_ms: coordinator_eth_height_check_interval_ms
     ],
     %{
       depositor: [finality_margin: deposit_finality_margin],
       exiter: [waits_for: :depositor, finality_margin: 0],
       in_flight_exit: [waits_for: :depositor, finality_margin: 0],
       piggyback: [waits_for: :in_flight_exit, finality_margin: 0]
     }}
  end
end
