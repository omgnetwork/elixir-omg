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

defmodule OMG.Performance.BazantineEventsTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.ChildChain.Integration.Fixtures
  use OMG.Watcher.Fixtures
  alias OMG.Eth
  require OMG.Utxo

  alias OMG.Eth
  alias OMG.Eth.RootChain
  alias OMG.Performance
  alias OMG.State.Transaction
  alias OMG.Utxo
  alias OMG.Watcher.HttpRPC.Client
  alias OMG.Watcher.TestHelper

  @moduletag :integration
  @moduletag timeout: 70_000

  @tag fixtures: [:watcher, :child_chain, :contract]
  test "time response for asking for exit data", %{contract: %{contract_addr: contract}} do
    dos_users = 10
    ntx_to_send = 10
    spenders = generate_users(2)

    IO.puts("""
    dos users: #{dos_users}
    spenders: #{length(spenders)}
    ntx_toxend: #{ntx_to_send}
    exits per dos user: #{length(spenders) * ntx_to_send}
    total exits: #{length(spenders) * ntx_to_send * dos_users}
    """)

    # TODO find another way to wait for data generations, maybe smoke_test_statistics
    Performance.start_extended_perftest(ntx_to_send, spenders, contract)
    Process.sleep(4000)

    statistics =
      Enum.map(1..dos_users, fn _ ->
        Task.async(fn ->
          stream_exit_data_blocks = generate_exit_info() |> Enum.map(&get_lazy_exit_data/1) |> Enum.to_list()
          :timer.tc(fn -> stream_exit_data_blocks |> Enum.map(&Enum.to_list(&1)) end)
        end)
      end)
      |> Enum.map(fn task ->
        {time, exit_data_blocks} = Task.await(task, :infinity)

        {time / 1_000,
         exit_data_blocks
         |> Enum.map(fn exits_utxo ->
           Enum.reduce(exits_utxo, %{correct: 0, error: 0}, fn
             %{"proof" => _}, stats -> Map.update(stats, :correct, 0, &(&1 + 1))
             _, stats -> Map.update(stats, :error, 0, &(&1 + 1))
           end)
         end)
         |> Enum.reduce(%{error: 0, correct: 0}, fn %{error: error, correct: correct}, statistics ->
           Map.update(statistics, :error, 0, &(&1 + error))
           |> Map.update(:correct, 0, &(&1 + correct))
         end)}
      end)

    times = statistics |> Enum.map(&elem(&1, 0))
    correct_exits = statistics |> Enum.map(&Map.get(elem(&1, 1), :correct)) |> Enum.sum()
    error_exits = statistics |> Enum.map(&Map.get(elem(&1, 1), :error)) |> Enum.sum()

    IO.puts("""
    max dos user time: #{Enum.max(times)}
    min dos user time: #{Enum.min(times)}
    average dos user time: #{Enum.sum(times) / length(times)}
    correct exits: #{correct_exits}
    error exits: #{error_exits}
    """)

    assert error_exits == 0
  end

  defp generate_exit_info do
    %{interval: interval, counter: length_block} = block_info()

    Enum.shuffle(1..length_block)
    |> Stream.map(&generate_exit_info_block(&1 * interval))
  end

  defp block_info do
    {:ok, interval} = RootChain.get_child_block_interval()
    {:ok, top_block} = RootChain.get_mined_child_block()
    %{interval: interval, counter: trunc(top_block / interval)}
  end

  defp generate_exit_info_block(blknum) do
    {:ok, {block_hash, _timestamp}} = RootChain.get_child_chain(blknum)
    child_chain_url = Application.get_env(:omg_watcher, :child_chain_url)
    {:ok, block} = Client.get_block(block_hash, child_chain_url)

    Enum.shuffle(Enum.zip(block.transactions, Stream.iterate(0, &(&1 + 1))))
    |> Enum.map(fn {tx, nr} ->
      recover_tx = Transaction.Recovered.recover_from!(tx)
      outputs = Transaction.get_outputs(recover_tx)
      position = Utxo.position(blknum, nr, Enum.random(0..(length(outputs) - 1)))
      utxo_pos = Utxo.Position.encode(position)
      %{utxo_pos: utxo_pos, recover_tx: recover_tx}
    end)
  end

  defp get_lazy_exit_data(utxos) when is_list(utxos) do
    Stream.map(utxos, &get_exit_data/1)
  end

  defp get_exit_data(%{utxo_pos: utxo_pos}) do
    TestHelper.get_exit_data(utxo_pos)
  rescue
    error in MatchError -> error
  end

  defp generate_users(size, opts \\ [initial_funds: trunc(:math.pow(10, 18))]) do
    async_generate_user = fn _ -> Task.async(fn -> generate_user(opts) end) end

    Enum.chunk_every(1..size, 10)
    |> Enum.map(fn chunk ->
      Enum.map(chunk, async_generate_user)
      |> Enum.map(&Task.await(&1, :infinity))
    end)
    |> List.flatten()
  end

  defp generate_user(opts) do
    user = OMG.TestHelper.generate_entity()
    {:ok, _user} = Eth.DevHelpers.import_unlock_fund(user, opts)
    user
  end
end
