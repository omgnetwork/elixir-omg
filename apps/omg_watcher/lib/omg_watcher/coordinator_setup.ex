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

defmodule OMG.Watcher.CoordinatorSetup do
  @moduledoc """
  The setup of `OMG.RootChainCoordinator` for the Watcher - configures the relations between different event listeners
  """

  alias OMG.Watcher.Configuration

  @doc """
  The `OMG.RootChainCoordinator` setup for the `OMG.Watcher` app. Summary of the configuration:

    - deposits are recognized after `deposit_finality_margin`. Should take child chain server's setting into account
    - exit-related events are recognized after `exit_finality_margin`
    - exit-related events wait for deposits and themselves respectively, in case of the inter-dependent IFE events
    - exit finalization-related events wait for deposits and blocks to never finalize not-yet created UTXOs
    - blocks wait for deposits _BUT_ they advance by the finality margin of the `depositor`. In practice this means that
      blocks wait for deposits when syncing, but don't when processing fresh events. This allows for 0-confirmation
      finality of child chain transaction (the user is responsible for deciding on finality and confirmations)
  """
  def coordinator_setup() do
    finality_margin = Configuration.exit_finality_margin()
    deposit_finality_margin = OMG.Configuration.deposit_finality_margin()

    %{
      depositor: [finality_margin: deposit_finality_margin],
      block_getter: [
        waits_for: [depositor: :no_margin],
        finality_margin: 0
      ],
      exit_processor: [waits_for: :depositor, finality_margin: finality_margin],
      exit_finalizer: [
        waits_for: [:depositor, :block_getter, :exit_processor],
        finality_margin: finality_margin
      ],
      exit_challenger: [waits_for: :exit_processor, finality_margin: finality_margin],
      in_flight_exit_processor: [waits_for: :depositor, finality_margin: finality_margin],
      piggyback_processor: [waits_for: :in_flight_exit_processor, finality_margin: finality_margin],
      competitor_processor: [waits_for: :in_flight_exit_processor, finality_margin: finality_margin],
      challenges_responds_processor: [waits_for: :competitor_processor, finality_margin: finality_margin],
      piggyback_challenges_processor: [waits_for: :piggyback_processor, finality_margin: finality_margin],
      ife_exit_finalizer: [
        waits_for: [:depositor, :block_getter, :in_flight_exit_processor, :piggyback_processor],
        finality_margin: finality_margin
      ]
    }
  end
end
