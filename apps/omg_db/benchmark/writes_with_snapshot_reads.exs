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
# Usage: mix run apps/omg_db/benchmark/writes_with_snapshot_reads.exs
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

  # Writes

  def populate_utxos_every(interval_ms, :infinity, num_utxos, db_ref) do
    populate_utxos_every(interval_ms, -1, num_utxos, db_ref)
  end

  def populate_utxos_every(_, 0, _, _), do: :ok

  def populate_utxos_every(interval_ms, times, num_utxos, db_ref) do
    :ok = populate_utxos(db_ref, num_utxos)
    :ok = Process.sleep(interval_ms)

    populate_utxos_every(interval_ms, times - 1, num_utxos, db_ref)
  end

  # Reads

  def read_utxos_every(interval_ms, :infinity, db_ref, snapshot: snapshot) do
    read_utxos_every(interval_ms, -1, db_ref, snapshot: snapshot)
  end

  def read_utxos_every(_, 0, _, _), do: :ok

  def read_utxos_every(interval_ms, times, db_ref, snapshot: :direct) do
    {:ok, iterator} = :rocksdb.iterator(db_ref, prefix_same_as_start: true)
    move_iterator = :rocksdb.iterator_move(iterator, {:seek, "utxoi"})
    raw_utxos = Enum.reverse(search(db_ref, iterator, move_iterator, []))
    {:ok, _utxos} = OMG.DB.RocksDB.Core.decode_values(raw_utxos)

    :ok = Process.sleep(interval_ms)
    read_utxos_every(interval_ms, times - 1, db_ref, snapshot: :direct)
  end

  def read_utxos_every(interval_ms, times, db_ref, snapshot: :snapshot) do
    {:ok, snapshot_ref} = :rocksdb.snapshot(db_ref)

    {:ok, iterator} = :rocksdb.iterator(db_ref, snapshot: snapshot_ref, prefix_same_as_start: true)
    move_iterator = :rocksdb.iterator_move(iterator, {:seek, "utxoi"})
    raw_utxos = Enum.reverse(search(db_ref, iterator, move_iterator, []))
    {:ok, _utxos} = OMG.DB.RocksDB.Core.decode_values(raw_utxos)

    :ok = :rocksdb.release_snapshot(snapshot_ref)
    :ok = Process.sleep(interval_ms)
    read_utxos_every(interval_ms, times - 1, db_ref, snapshot: :snapshot)
  end

  # Copied from OMG.DB.RocksDB.Core.search/4
  def search(_reference, _iterator, {:error, :invalid_iterator}, acc), do: acc
  def search(reference, iterator, {:ok, _key, value}, acc), do: do_search(reference, iterator, [value | acc])

  defp do_search(reference, iterator, acc) do
    case :rocksdb.iterator_move(iterator, :next) do
      {:error, :invalid_iterator} ->
        # we've reached the end
        :rocksdb.iterator_close(iterator)
        acc

      {:ok, _key, value} ->
        do_search(reference, iterator, [value | acc])
    end
  end

  def populate_utxos(db_ref, num_utxos) do
    1..num_utxos
    |> Enum.map(fn _index ->
      output_data = %{
        creating_txhash: random_bytes(),
        output: %{owner: random_bytes(), currency: random_bytes(), amount: 1_000_000_000, output_type: 1}
      }

      # Randomized `{blknum, txindex, oindex}`
      # Assuming potential storage of 100,000 blocks, 7,000 transactions per block and all outputs used
      {:put, :utxo, {{:rand.uniform(100_000) * 1000, :rand.uniform(7000), :rand.uniform(4) - 1}, output_data}}
    end)
    |> multi_update(db_ref)
  end

  defp random_bytes() do
    0..255 |> Enum.shuffle() |> :erlang.list_to_binary()
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
    "utxo write" => fn {_dir, db_ref, _load_generator_pid, num_utxos} ->
      :ok = Helper.populate_utxos(db_ref, num_utxos)
    end
  },
  inputs: %{
    "1 utxo writes, no reads" => {1, :no_read},
    "1 utxo writes, direct reads" => {1, :direct},
    "1 utxo writes, snapshot reads" => {1, :snapshot},

    "100 utxo writes, no reads" => {100, :no_read},
    "100 utxo writes, direct reads" => {100, :direct},
    "100 utxo writes, snapshot reads" => {100, :snapshot},

    "1,000 utxo writes, no reads" => {1_000, :no_read},
    "1,000 utxo writes, direct reads" => {1_000, :direct},
    "1,000 utxo writes, snapshot reads" => {1_000, :snapshot},
  },
  before_scenario: fn
    {num_utxos, :no_read} ->
      # Start with 10_000 utxos for all scenarios
      {:ok, dir} = Helper.setup_db_with_data(10_000)

      setup = [{:create_if_missing, false}, {:prefix_extractor, {:fixed_prefix_transform, 5}}]
      {:ok, db_ref} = :rocksdb.open(String.to_charlist(dir), setup)

      {:ok, load_generator_pid} =
        Task.start_link(fn ->
          :noop
        end)

      {dir, db_ref, load_generator_pid, num_utxos}

    {num_utxos, snapshot} ->
      # Start with 10_000 utxos for all scenarios
      {:ok, dir} = Helper.setup_db_with_data(10_000)

      setup = [{:create_if_missing, false}, {:prefix_extractor, {:fixed_prefix_transform, 5}}]
      {:ok, db_ref} = :rocksdb.open(String.to_charlist(dir), setup)

      {:ok, load_generator_pid} =
        Task.start_link(fn ->
          Helper.read_utxos_every(100, :infinity, db_ref, snapshot: snapshot)
        end)

      {dir, db_ref, load_generator_pid, num_utxos}
  end,
  after_scenario: fn {dir, db_ref, load_generator_pid, _num_utxos} ->
    true = Process.exit(load_generator_pid, :kill)
    :ok = :rocksdb.close(db_ref)
    {:ok, _} = File.rm_rf(dir)
  end,
  time: 30,
  memory_time: 10
)
