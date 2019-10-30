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

  ## start_dos_get_exits runs a test to get exit data for given 10 positions for 3 users

  ```
  mix run --no-start -e \
    '
      OMG.Performance.ByzantineEvents.Generators.stream_utxo_positions() |>
      Enum.take(10) |> OMG.Performance.ByzantineEvents.start_dos_get_exits(3)
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

  alias OMG.Performance.ByzantineEvents.Workers
  alias OMG.Performance.HttpRPC.WatcherClient
  alias Support.WaitFor

  alias OMG.Utxo

  require Utxo

  @type stats_t :: %{
          span_ms: non_neg_integer(),
          corrects_count: non_neg_integer(),
          errors_count: non_neg_integer()
        }

  @watcher_url Application.get_env(:omg_performance, :watcher_url)
  @micros_in_millisecond 1000

  @doc """
  For given utxo positions and given number of users start fetching exit data from Watcher.
  User tasks are run asynchronously, each user receives the same positions list, shuffle its order
  and call Watcher for exit data sequentially one position at a time.
  """
  @spec start_dos_get_exits([non_neg_integer()], [OMG.TestHelper.entity()], watcher_url: binary()) ::
          stats_t()
  def start_dos_get_exits(positions, dos_users, watcher_url \\ @watcher_url) do
    1..dos_users
    |> Enum.map(fn _ ->
      # FIXME: why do we even need to do this concurently ???
      exit_fn = Workers.get_exit_data_worker(positions, watcher_url)
      Task.async(exit_fn)
    end)
    |> Enum.map(&compute_std_exits_statistics/1)
  end

  def start_many_exits(positions, owner_address, watcher_url \\ @watcher_url) do
    exit_fn = Workers.get_exit_data_worker(positions, watcher_url)
    task = Task.async(exit_fn)
    {_time, exits} = Task.await(task, :infinity)
    # FIXME: all uses of valid_exit_data should go. We also shouldn't "compute statistics". Let's fail on failure and
    #        figure out time it took to get the response only
    true = Enum.all?(exits, &valid_exit_data/1) || {:error, :not_all_exit_data_successful, Enum.zip(positions, exits)}

    exits
    |> Enum.map(fn {:ok, composed_exit} ->
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

  def get_byzantine_events(event_name, watcher_url \\ @watcher_url) do
    {:ok, status_response} = WatcherClient.get_status(watcher_url)

    status_response
    |> Access.get(:byzantine_events)
    |> Enum.filter(&(&1["event"] == event_name))
  end

  def get_challenge_data(positions, watcher_url \\ @watcher_url) do
    positions
    |> Enum.map(fn position ->
      WatcherClient.get_exit_challenge(position, watcher_url)
    end)
  end

  def challenge_many_exits(challenge_responses, challenger_address, watcher_url \\ @watcher_url) do
    challenge_responses
    # FIXME: move the :ok pattern match elsewhere (same with exits)
    |> Enum.map(fn {:ok, challenge} ->
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
  Fetches utxo positions for a given users list.
  """
  @spec get_exitable_utxos([%{addr: binary()}], watcher_url: binary()) :: [non_neg_integer()]
  def get_exitable_utxos(entities, watcher_url \\ @watcher_url)

  def get_exitable_utxos(users, watcher_url) when is_list(users),
    do: Enum.map(users, &get_exitable_utxos(&1, watcher_url)) |> Enum.concat()

  def get_exitable_utxos(%{addr: addr}, watcher_url) when is_binary(addr),
    do: get_exitable_utxos(addr, watcher_url)

  def get_exitable_utxos(addr, watcher_url) do
    {:ok, utxos} = WatcherClient.get_exitable_utxos(addr, watcher_url)
    utxos
  end

  # FIXME: nicen the optional arguments here
  def watcher_synchronize(root_chain_height \\ nil, watcher_url \\ @watcher_url) do
    WaitFor.repeat_until_ok(fn -> watcher_synchronized?(root_chain_height, watcher_url) end)
    # NOTE: allowing some more time for the dust to settle on the synced Watcher
    # otherwise some of the freshest UTXOs to exit will appear as missing on the Watcher
    # related issue to remove this `sleep` and fix properly is https://github.com/omisego/elixir-omg/issues/1031
    Process.sleep(2000)
  end

  defp valid_exit_data({:ok, response}), do: valid_exit_data(response)
  defp valid_exit_data(%{proof: _}), do: true
  defp valid_exit_data(_), do: false

  defp compute_std_exits_statistics(task) do
    {time, exits} = Task.await(task, :infinity)
    valid? = Enum.map(exits, &valid_exit_data/1)

    %{
      span_ms: div(time, @micros_in_millisecond),
      corrects_count: Enum.count(valid?, & &1),
      errors_count: Enum.count(valid?, &(!&1))
    }
  end

  # This function is prepared to be called in `WaitFor.repeat_until_ok`.
  # It repeatedly ask for Watcher's `/status.get` until Watcher consume mined block
  defp watcher_synchronized?(root_chain_height, watcher_url) do
    # FIXME: why the with/else? this shouldn't fail!
    with {:ok, status} <- WatcherClient.get_status(watcher_url),
         # FIXME: nicen this, the waitfor function expects some weird output for some reason, so we're conforming
         {:ok, _} = response <- watcher_synchronized_to_mined_block?(status),
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
