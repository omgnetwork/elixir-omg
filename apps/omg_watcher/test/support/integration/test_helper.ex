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

defmodule OMG.Watcher.Integration.TestHelper do
  @moduledoc """
  Common helper functions that are useful when integration-testing the watcher
  """

  alias OMG.Eth
  alias OMG.State
  alias OMG.Utxo

  require Utxo
  import OMG.Watcher.TestHelper

  def wait_for_byzantine_events(event_names, timeout) do
    fn ->
      %{"byzantine_events" => emitted_events} = success?("/status.get")
      emitted_event_names = Enum.map(emitted_events, &String.to_atom(&1["event"]))

      all_events =
        Enum.all?(event_names, fn x ->
          x in emitted_event_names
        end)

      if all_events,
        do: {:ok, emitted_event_names},
        else: :repeat
    end
    |> wait_for(timeout)
  end

  def wait_for_block_fetch(block_nr, timeout) do
    # TODO query to State used in tests instead of an event system, remove when event system is here
    fn ->
      if State.get_status() |> elem(0) <= block_nr,
        do: :repeat,
        else: {:ok, block_nr}
    end
    |> wait_for(timeout)

    # write to db seems to be async and wait_for_block_fetch would return too early, so sleep
    # leverage `block` events if they get implemented
    Process.sleep(100)
  end

  defp wait_for(func, timeout) do
    fn ->
      Eth.WaitFor.repeat_until_ok(func)
    end
    |> Task.async()
    |> Task.await(timeout)
  end

  @doc """
  We need to wait on both a margin of eth blocks and exit processing
  """
  def wait_for_exit_processing(exit_eth_height, timeout \\ 5_000) do
    exit_finality = Application.fetch_env!(:omg_watcher, :exit_finality_margin) + 1
    Eth.DevHelpers.wait_for_root_chain_block(exit_eth_height + exit_finality, timeout)
    # wait some more to ensure exit is processed
    Process.sleep(Application.fetch_env!(:omg, :ethereum_events_check_interval_ms) * 2)
  end
end
