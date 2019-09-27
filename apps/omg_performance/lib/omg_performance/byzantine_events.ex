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
    %{time: 232000, corrects_count: 10, errors_count: 0},
    %{time: 221500, corrects_count: 10, errors_count: 0},
    %{time: 219900, corrects_count: 10, errors_count: 0},
  ]
  ```

  where time is expressed in microseconds and the sum of `corrects_count + errors_count` should equal to
  `length(positions)`. If all passed position was unspent there should be no errors.
  """

  alias OMG.Eth
  alias OMG.Performance.ByzantineEvents.DoSExitWorker
  alias OMG.Utils.HttpRPC.Client
  alias OMG.Utils.HttpRPC.Encoding

  @type stats_t :: %{
          span_ms: non_neg_integer(),
          corrects_count: non_neg_integer(),
          errors_count: non_neg_integer()
        }

  @watcher_url Application.get_env(:byzantine_events, :watcher_url)
  @micros_in_millisecond 1000

  @doc """
  For given utxo positions and given number of users start fetching exit data from Watcher.
  User tasks are run asynchronously, each user receives the same positions list, shuffle its order
  and call Watcher for exit data sequentially one position at a time.
  """
  @spec start_dos_get_exits([non_neg_integer()], [%{addr: binary(), priv: binary()}], watcher_url: binary()) ::
          stats_t()
  def start_dos_get_exits(positions, dos_users, url \\ @watcher_url) do
    1..dos_users
    |> Enum.map(fn _ -> DoSExitWorker.get_exits_fun(positions, url) |> Task.async() end)
    |> Enum.map(&compute_std_exits_statistics/1)
  end

  @doc """
  Fetches utxo positions for a given users list.
  """
  @spec get_exitable_utxos([%{addr: binary()}], watcher_url: binary()) :: [non_neg_integer()]
  def get_exitable_utxos(entities, watcher_url \\ @watcher_url)

  def get_exitable_utxos(addr, watcher_url) when is_binary(addr) do
    {:ok, utxos} = Client.get_exitable_utxos(addr, watcher_url)
    utxos
  end

  def get_exitable_utxos(%{addr: addr}, watcher_url) when is_binary(addr),
    do: Encoding.to_hex(addr) |> get_exitable_utxos(watcher_url)

  def get_exitable_utxos(users, watcher_url) when is_list(users),
    do: Enum.map(users, &get_exitable_utxos(&1, watcher_url)) |> Enum.concat()

  def watcher_synchronize(watcher_url \\ @watcher_url) do
    Eth.WaitFor.repeat_until_ok(fn ->
      with {:ok,
            %{
              last_mined_child_block_number: last_validated_child_block_number,
              last_validated_child_block_number: last_validated_child_block_number
            }} <- Client.get_status(watcher_url) do
        {:ok, last_validated_child_block_number}
      else
        _ -> :repeat
      end
    end)
  end

  def watcher_synchronize_service(expected_service, min_service_height, watcher_url \\ @watcher_url) do
    Eth.WaitFor.repeat_until_ok(fn ->
      with {:ok, %{services_synced_heights: services_synced_heights}} <- Client.get_status(watcher_url),
           %{"height" => height} when height >= min_service_height <-
             Enum.find(services_synced_heights, &match?(%{"service" => ^expected_service}, &1)) do
        {:ok, height}
      else
        _ -> :repeat
      end
    end)
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
end
