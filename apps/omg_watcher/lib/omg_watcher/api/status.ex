# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.Watcher.API.Status do
  @moduledoc """
  Watcher status API
  """

  alias OMG.Eth
  alias OMG.State
  alias OMG.Watcher.BlockGetter
  alias OMG.Watcher.Event
  alias OMG.Watcher.ExitProcessor

  @opaque t() :: %{
            last_validated_child_block_number: non_neg_integer(),
            last_mined_child_block_number: non_neg_integer(),
            last_mined_child_block_timestamp: non_neg_integer(),
            eth_syncing: boolean(),
            byzantine_events: list(Event.t())
          }

  @doc """
  Returns status of the watcher. Status consists of last validated child block number,
  last mined child block number and it's timestamp, and a flag indicating if watcher is syncing with Ethereum.
  """
  @spec get_status() :: {:ok, t()} | {:error, atom}
  def get_status do
    with {:ok, last_mined_child_block_number} <- Eth.RootChain.get_mined_child_block(),
         {:ok, {_root, last_mined_child_block_timestamp}} <-
           Eth.RootChain.get_child_chain(last_mined_child_block_number),
         {:ok, child_block_interval} <- Eth.RootChain.get_child_block_interval() do
      {state_current_block, _} = State.get_status()

      {_, events_processor} = ExitProcessor.check_validity()
      {_, events_block_getter} = BlockGetter.get_events()
      {:ok, in_flight_exits} = ExitProcessor.get_active_in_flight_exits()

      status = %{
        last_validated_child_block_number: state_current_block - child_block_interval,
        last_mined_child_block_number: last_mined_child_block_number,
        last_mined_child_block_timestamp: last_mined_child_block_timestamp,
        eth_syncing: Eth.syncing?(),
        byzantine_events: events_processor ++ events_block_getter,
        in_flight_exits: in_flight_exits
      }

      {:ok, status}
    else
      :error -> {:error, :unknown}
      {:error, _} = error -> error
    end
  end
end
