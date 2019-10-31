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

defmodule OMG.Performance.ByzantineEvents do
  @moduledoc """
  OMG network child chain server byzantine event test entrypoint. Setup and runs performance byzantine tests.

  # Usage

  See functions in this module for options available

  ## get_many_standard_exits runs a test to get exit data for given 10 positions for 3 users

  ```
  mix run --no-start -e \
    '
      OMG.Performance.Generators.stream_utxo_positions() |>
      Enum.take(10) |> OMG.Performance.ByzantineEvents.get_many_standard_exits(3)
    '
  ```

  __ASSUMPTIONS:__
  This test should be run on testnet filled with transactions make sure you followed instructions in `docs/demo_05.md`
  and `geth`, `omg_child_chain` and `omg_watcher` are running; and watcher is fully synced.

  Expected result of running the above command should looks like:

  ```
  [
    %{span_ms: 232000, corrects_count: 10, errors_count: 0},
    %{span_ms: 221500, corrects_count: 10, errors_count: 0},
    %{span_ms: 219900, corrects_count: 10, errors_count: 0},
  ]
  ```

  where the sum of `corrects_count + errors_count` should equal to `length(positions)`.
  If all passed position was unspent there should be no errors.
  """

  use OMG.Utils.LoggerExt

  alias OMG.Performance.HttpRPC.WatcherClient
  alias Support.WaitFor

  alias OMG.Utxo

  require Utxo

  @doc """
  For given utxo positions shuffle them and ask the watcher for exit data
  """
  # FIXME specs
  def get_many_standard_exits(exit_positions) do
    watcher_url = Application.fetch_env!(:omg_performance, :watcher_url)

    exit_positions
    |> Enum.shuffle()
    |> Enum.map(&WatcherClient.get_exit_data(&1, watcher_url))
    |> only_successes()
  end

  @doc """
  # FIXME do doc here
  """
  def start_many_exits(exit_positions, owner_address) do
    # FIXME: tidy this: do we provide it from the outside as with challenges?
    exit_positions
    |> get_many_standard_exits()
    |> Enum.map(fn composed_exit ->
      result =
        Support.RootChainHelper.start_exit(
          composed_exit.utxo_pos,
          composed_exit.txbytes,
          composed_exit.proof,
          owner_address
        )

      # FIXME: nicen
      {:ok, _} = Task.start(fn -> result |> Support.DevHelper.transact_sync!() end)
      result
    end)
    |> List.last()
    |> Support.DevHelper.transact_sync!()
  end

  def get_byzantine_events(event_name) do
    watcher_url = Application.fetch_env!(:omg_performance, :watcher_url)
    {:ok, status_response} = WatcherClient.get_status(watcher_url)

    status_response
    |> Access.get(:byzantine_events)
    |> Enum.filter(&(&1["event"] == event_name))
    |> postprocess_byzantine_events(event_name)
  end

  defp postprocess_byzantine_events(events, "invalid_exit"), do: Enum.map(events, & &1["details"]["utxo_pos"])

  @doc """
  For given utxo positions shuffle them and ask the watcher for challenge data. All positions must be invalid exits
  """
  def get_many_se_challenges(positions) do
    watcher_url = Application.fetch_env!(:omg_performance, :watcher_url)

    positions
    |> Enum.shuffle()
    |> Enum.map(&WatcherClient.get_exit_challenge(&1, watcher_url))
    |> only_successes()
  end

  def challenge_many_exits(challenge_responses, challenger_address) do
    watcher_url = Application.fetch_env!(:omg_performance, :watcher_url)

    challenge_responses
    |> Enum.map(fn challenge ->
      result =
        Support.RootChainHelper.challenge_exit(
          challenge.exit_id,
          challenge.exiting_tx,
          challenge.txbytes,
          challenge.input_index,
          challenge.sig,
          challenger_address
        )

      # FIXME: nicen dry etc
      {:ok, _} = Task.start(fn -> result |> Support.DevHelper.transact_sync!() end)
      result
    end)
    |> List.last()
    |> Support.DevHelper.transact_sync!()
  end

  @doc """
  Fetches utxo positions for a given user's address.

  Options:
    - :take - if not nil, will limit to this much results
  """
  def get_exitable_utxos(addr, opts \\ []) when is_binary(addr) do
    watcher_url = Application.fetch_env!(:omg_performance, :watcher_url)
    {:ok, utxos} = WatcherClient.get_exitable_utxos(addr, watcher_url)
    utxo_positions = Enum.map(utxos, & &1.utxo_pos)

    if opts[:take], do: Enum.take(utxo_positions, opts[:take]), else: utxo_positions
  end

  # FIXME: nicen the optional arguments here
  def watcher_synchronize(root_chain_height \\ nil) do
    watcher_url = Application.fetch_env!(:omg_performance, :watcher_url)
    _ = Logger.info("Waiting for the watcher to synchronize")
    WaitFor.repeat_until_ok(fn -> watcher_synchronized?(root_chain_height, watcher_url) end)
    # NOTE: allowing some more time for the dust to settle on the synced Watcher
    # otherwise some of the freshest UTXOs to exit will appear as missing on the Watcher
    # related issue to remove this `sleep` and fix properly is https://github.com/omisego/elixir-omg/issues/1031
    Process.sleep(2000)
    _ = Logger.info("Watcher synchronized")
  end

  defp only_successes(responses), do: Enum.map(responses, fn {:ok, response} -> response end)

  # This function is prepared to be called in `WaitFor.repeat_until_ok`.
  # It repeatedly ask for Watcher's `/status.get` until Watcher consume mined block
  defp watcher_synchronized?(root_chain_height, watcher_url) do
    {:ok, status} = WatcherClient.get_status(watcher_url)
    # FIXME: nicen this, the waitfor function expects some weird output for some reason, so we're conforming
    with {:ok, _} = response <- watcher_synchronized_to_mined_block?(status),
         true <- root_chain_synced?(root_chain_height, status) do
      response
    else
      _ -> :repeat
    end
  end

  defp root_chain_synced?(nil, _), do: true

  defp root_chain_synced?(root_chain_height, status) do
    status
    |> Access.get(:services_synced_heights)
    |> Enum.all?(&(&1["height"] >= root_chain_height))
  end

  defp watcher_synchronized_to_mined_block?(%{
         last_mined_child_block_number: last_mined_child_block_number,
         last_validated_child_block_number: last_validated_child_block_number
       })
       when last_mined_child_block_number == last_validated_child_block_number and
              last_mined_child_block_number > 0 do
    _ = Logger.debug("Synced to blknum: #{last_validated_child_block_number}")
    {:ok, last_validated_child_block_number}
  end

  defp watcher_synchronized_to_mined_block?(_), do: :repeat
end
