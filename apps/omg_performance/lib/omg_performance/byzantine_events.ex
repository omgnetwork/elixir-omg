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

  require OMG.Utxo

  alias OMG.Eth
  alias OMG.Eth.RootChain
  alias OMG.State.Transaction
  alias OMG.Utxo
  alias OMG.Watcher.HttpRPC.Client
  alias OMG.Watcher.TestHelper

  def start_dos_get_exits(dos_users, positions) do
    Enum.map(1..dos_users, fn _ -> worker_dos_exit(positions) end)
    |> Enum.map(&Task.await(&1, :infinity))
  end

  defp worker_dos_exit(exit_positions) do
    worker = fn exit_positions ->
      Enum.map(exit_positions, fn position ->
        get_exit_data(position) |> valid_exit_data()
      end)
    end

    Task.async(fn ->
      exit_positions = Enum.shuffle(exit_positions)
      {time, valid?} = :timer.tc(fn -> worker.(exit_positions) end)
      %{time: time, correct: Enum.count(valid?, & &1), error: Enum.count(valid?, &(!&1))}
    end)
  end

  def valid_exit_data(%{"proof" => _}), do: true
  def valid_exit_data(_), do: false

  def stream_tx_positions do
    block_stream()
    |> Stream.map(&to_position_list(&1))
    |> Stream.concat()
  end

  defp block_stream do
    {:ok, interval} = RootChain.get_child_block_interval()

    Stream.iterate(1, &(&1 + 1))
    |> Stream.map(&get_block!(&1 * interval))
  end

  defp get_block!(blknum) do
    child_chain_url = Application.get_env(:omg_watcher, :child_chain_url)

    {:ok, block} =
      Enum.find(
        Stream.iterate(0, fn _ ->
          with {:ok, {block_hash, _timestamp}} <- RootChain.get_child_chain(blknum) do
            Client.get_block(block_hash, child_chain_url)
          end
        end),
        fn
          {:ok, _} ->
            true

          _err ->
            Process.sleep(100)
            false
        end
      )

    block
  end

  defp to_position_list(block) do
    Stream.with_index(block.transactions)
    |> Stream.map(fn {tx, index} ->
      recover_tx = Transaction.Recovered.recover_from!(tx)
      outputs = Transaction.get_outputs(recover_tx)
      Enum.map(0..(length(outputs) - 1), &(Utxo.position(block.number, index, &1) |> Utxo.Position.encode()))
    end)
    |> Stream.concat()
  end

  def get_exit_data(utxo_pos) do
    TestHelper.get_exit_data(utxo_pos)
  rescue
    error -> error
  end

  def generate_users(size, opts \\ [initial_funds: trunc(:math.pow(10, 18))]) do
    async_generate_user = fn _ -> Task.async(fn -> generate_user(opts) end) end

    1..size
    |> Enum.chunk_every(10)
    |> Enum.map(fn chunk ->
      Enum.map(chunk, async_generate_user)
      |> Enum.map(&Task.await(&1, :infinity))
    end)
    |> List.flatten()
  end

  def generate_user(opts) do
    user = OMG.TestHelper.generate_entity()
    {:ok, _user} = Eth.DevHelpers.import_unlock_fund(user, opts)
    user
  end
end
