# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.Watcher.Integration.TestHelper do
  @moduledoc """
  Common helper functions that are useful when integration-testing the watcher
  """

  alias OMG.State
  alias OMG.Utxo
  alias Support.DevHelper
  alias Support.RootChainHelper
  alias Support.WaitFor
  alias Support.WatcherHelper

  require Utxo

  def wait_for_byzantine_events(event_names, timeout) do
    fn ->
      %{"byzantine_events" => emitted_events} = WatcherHelper.success?("/status.get")
      emitted_event_names = Enum.map(emitted_events, &String.to_atom(&1["event"]))

      all_events =
        Enum.all?(event_names, fn x ->
          x in emitted_event_names
        end)

      if all_events,
        do: {:ok, emitted_event_names},
        else: :repeat
    end
    |> WaitFor.ok(timeout)
  end

  def wait_for_block_fetch(block_nr, timeout) do
    # TODO query to State used in tests instead of an event system, remove when event system is here
    fn ->
      if State.get_status() |> elem(0) <= block_nr,
        do: :repeat,
        else: {:ok, block_nr}
    end
    |> WaitFor.ok(timeout)

    # write to db seems to be async and wait_for_block_fetch would return too early, so sleep
    # leverage `block` events if they get implemented
    Process.sleep(100)
  end

  @doc """
  We need to wait on both a margin of eth blocks and exit processing
  """
  def wait_for_exit_processing(exit_eth_height, timeout \\ 5_000) do
    exit_finality = Application.fetch_env!(:omg_watcher, :exit_finality_margin) + 1
    DevHelper.wait_for_root_chain_block(exit_eth_height + exit_finality, timeout)
    # wait some more to ensure exit is processed
    Process.sleep(Application.fetch_env!(:omg, :ethereum_events_check_interval_ms) * 2)
  end

  def process_exits(vault_id, token, user) do
    min_exit_period_ms = Application.fetch_env!(:omg_eth, :min_exit_period_seconds) * 1000
    # enough to wait out the exit period on the contract
    Process.sleep(2 * min_exit_period_ms)

    {:ok, %{"status" => "0x1", "blockNumber" => process_eth_height, "logs" => logs}} =
      RootChainHelper.process_exits(vault_id, token, 0, 1, user.addr) |> Support.DevHelper.transact_sync!()

    # status 0x1 doesn't yet mean much. To smoke test the success of the processing (exits actually processed) we
    # take a look at the logs. Single entry means no logs were processed (it is the `ProcessedExitsNum`, that always
    # gets emmitted)
    true = length(logs) > 1 || {:error, :looks_like_no_exits_were_processed}

    # to have the new event fully acknowledged by the services, wait the finality margin
    exit_finality_margin = Application.fetch_env!(:omg_watcher, :exit_finality_margin)
    DevHelper.wait_for_root_chain_block(process_eth_height + exit_finality_margin + 1)
    # just a little more to ensure events are recognized by services
    check_interval_ms = Application.fetch_env!(:omg, :ethereum_events_check_interval_ms)
    Process.sleep(3 * check_interval_ms)
    :ok
  end
end
