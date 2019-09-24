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
  OMG network child chain server byzantine event test. Setup and runs performance byzantine tests.
  """

  alias OMG.Eth
  alias OMG.Utils.HttpRPC.Client
  alias OMG.Utils.HttpRPC.Encoding

  @watcher_url Application.get_env(:byzantine_events, :watcher_url)

  def start_dos_get_exits(dos_users, positions, url \\ @watcher_url) do
    Enum.map(1..dos_users, fn _ -> worker_dos_get_exit(positions, url) end)
    |> Enum.map(fn task ->
      {time, exits} = Task.await(task, :infinity)
      valid? = Enum.map(exits, &valid_exit_data/1)
      %{time: time, corrects_count: Enum.count(valid?, & &1), errors_count: Enum.count(valid?, &(!&1))}
    end)
  end

  defp worker_dos_get_exit(exit_positions, url) do
    worker = fn exit_positions ->
      Enum.map(exit_positions, fn position ->
        get_exit_data(position, url)
      end)
    end

    Task.async(fn ->
      exit_positions = Enum.shuffle(exit_positions)
      :timer.tc(fn -> worker.(exit_positions) end)
    end)
  end

  def get_exitable_utxos(addr, watcher_url \\ @watcher_url)

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

  defp get_exit_data(utxo_pos, watcher_url) do
    Client.get_exit_data(utxo_pos, watcher_url)
  rescue
    error -> error
  end

  defp valid_exit_data({:ok, respons}), do: valid_exit_data(respons)
  defp valid_exit_data(%{proof: _}), do: true
  defp valid_exit_data(_), do: false
end
