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

#
# Usage: mix run apps/omg_db/benchmark/utxo_get_breakdown.exs
#

defmodule OMG.DB.Benchmark.Helper do
  @moduledoc false

  @doc """
  Initialize a new rocksdb database in a temp directory
  and populate it with the given number of utxos.
  """
  def setup_db_with_data(num_utxos) do
    {:ok, dir} = Briefly.create(directory: true)
    :ok = OMG.DB.RocksDB.Server.init_storage(dir)

    setup = [{:create_if_missing, false}, {:prefix_extractor, {:fixed_prefix_transform, 5}}]
    db_path = String.to_charlist(dir)
    {:ok, db_ref} = :rocksdb.open(db_path, setup)

    :ok = populate_utxos(db_ref, num_utxos)

    # Closing the instance for data population, each test will start again with their own config
    :ok = :rocksdb.close(db_ref)
    {:ok, dir}
  end

  def populate_utxos_every(interval_ms, :infinity, num_utxos, db_ref) do
    populate_utxos_every(interval_ms, -1, num_utxos, db_ref)
  end

  def populate_utxos_every(_, 0, _, _), do: :ok

  def populate_utxos_every(interval_ms, times, num_utxos, db_ref) do
    :ok = populate_utxos(db_ref, num_utxos)
    :ok = Process.sleep(interval_ms)

    populate_utxos_every(interval_ms, times - 1, num_utxos, db_ref)
  end

  # Copied from OMG.DB.RocksDB.Core.search/4
  def search(_reference, _iterator, {:error, :invalid_iterator}, acc), do: acc
  def search(reference, iterator, {:ok, _key, value}, acc), do: do_search(reference, iterator, [value | acc])

  def do_search(reference, iterator, acc) do
    case :rocksdb.iterator_move(iterator, :next) do
      {:error, :invalid_iterator} ->
        # we've reached the end
        :rocksdb.iterator_close(iterator)
        acc

      {:ok, _key, value} ->
        do_search(reference, iterator, [value | acc])
    end
  end

  defp random_bytes() do
    0..255 |> Enum.shuffle() |> :erlang.list_to_binary()
  end

  def populate_utxos(db_ref, num_utxos) do
    1..num_utxos
    |> Enum.map(fn _index ->
      output_data = %{
        creating_txhash: random_bytes(),
        output: %{owner: random_bytes(), currency: random_bytes(), amount: 1_000_000_000, output_type: 1}
      }

      # Randomized `{blknum, txindex, oindex}`
      # Assuming potential load of 100,000 blocks, 7,000 transactions per block and all outputs used
      {:put, :utxo, {{:rand.uniform(100_000) * 1000, :rand.uniform(7000), :rand.uniform(4) - 1}, output_data}}
    end)
    |> multi_update(db_ref)
  end

  # Stuff from OMG.DB.RocksDB.Core
  defp multi_update(db_updates, db_ref) do
    db_updates
    |> Enum.flat_map(&parse_multi_update/1)
    |> write(db_ref)
  end

  # Stuff from OMG.DB.RocksDB.Core
  defp parse_multi_update({:put, type, item}), do: [{:put, key_for_item(type, item), encode_value(type, item)}]
  defp parse_multi_update({:delete, type, item}), do: [{:delete, key(type, item)}]
  defp key_for_item(:utxo, {position, _utxo}), do: key(:utxo, position)
  defp key(:utxo, position), do: "utxoi" <> :erlang.term_to_binary(position)
  defp encode_value(_type, value), do: :erlang.term_to_binary(value)

  # Stuff from OMG.DB.RocksDB.Core
  defp write(operations, db_ref) do
    :rocksdb.write(db_ref, operations, [])
  end
end

alias OMG.DB.Benchmark.Helper

# Start
{:ok, _} = Application.ensure_all_started(:briefly)

# Benchmark run

Benchee.run(
  %{
    "iterate" => fn {_dir, db_ref, _load_generator_pid} ->
      {:ok, iterator} = :rocksdb.iterator(db_ref, prefix_same_as_start: true)
      move_iterator = :rocksdb.iterator_move(iterator, {:seek, "utxoi"})
      _raw_utxos = Helper.search(db_ref, iterator, move_iterator, [])
    end,
    "iterate_decode" => fn {_dir, db_ref, _load_generator_pid} ->
      {:ok, iterator} = :rocksdb.iterator(db_ref, prefix_same_as_start: true)
      move_iterator = :rocksdb.iterator_move(iterator, {:seek, "utxoi"})
      raw_utxos = Helper.search(db_ref, iterator, move_iterator, [])

      {:ok, _utxos} = OMG.DB.RocksDB.Core.decode_values(raw_utxos)
    end,
    "iterate_reverse_decode" => fn {_dir, db_ref, _load_generator_pid} ->
      {:ok, iterator} = :rocksdb.iterator(db_ref, prefix_same_as_start: true)
      move_iterator = :rocksdb.iterator_move(iterator, {:seek, "utxoi"})
      raw_utxos = Enum.reverse(Helper.search(db_ref, iterator, move_iterator, []))

      {:ok, _utxos} = OMG.DB.RocksDB.Core.decode_values(raw_utxos)
    end
  },
  inputs: %{
    "1,000 utxos" => 1000,
    "10,000 utxos" => 10_000,
    "100,000 utxos" => 100_000
  },
  before_scenario: fn num_utxos ->
    {:ok, dir} = Helper.setup_db_with_data(num_utxos)

    setup = [{:create_if_missing, false}, {:prefix_extractor, {:fixed_prefix_transform, 5}}]
    {:ok, db_ref} = :rocksdb.open(String.to_charlist(dir), setup)

    {:ok, load_generator_pid} =
      Task.start_link(fn ->
        # Every 100ms, populate outputs for 20 transactions with 4 outputs each
        Helper.populate_utxos_every(100, :infinity, 20 * 4, db_ref)
      end)

    {dir, db_ref, load_generator_pid}
  end,
  after_scenario: fn {dir, db_ref, load_generator_pid} ->
    true = Process.exit(load_generator_pid, :shutdown)
    :ok = :rocksdb.close(db_ref)
    {:ok, _} = File.rm_rf(dir)
  end,
  time: 10,
  memory_time: 2
)
