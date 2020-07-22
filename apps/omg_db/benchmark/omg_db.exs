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
# Usage: mix run apps/omg_db/benchmark/omg_db.exs
#

# Helper functions
random_bytes = fn -> 0..255 |> Enum.shuffle() |> :erlang.list_to_binary() end

setup_db_with_data = fn num_utxos ->
  {:ok, dir} = Briefly.create(directory: true)
  :ok = OMG.DB.RocksDB.Server.init_storage(dir)

  # Start the DB for data population
  {:ok, db} = GenServer.start_link(OMG.DB.RocksDB.Server, [db_path: dir, name: :benchmark_db])

  # Populate data
  1..num_utxos
  |> Enum.map(fn index ->
    output_data = %{
      creating_txhash: random_bytes.(),
      output: %{owner: random_bytes.(), currency: random_bytes.(), amount: 1_000_000_000, output_type: 1}
    }

    # {blknum, txindex, oindex}
    {:put, :utxo, {{index, :rand.uniform(4000), :rand.uniform(4) - 1}, output_data}}
  end)
  |> OMG.DB.multi_update(db)

  # Clean up data initialization
  :ok = GenServer.stop(db)

  {:ok, dir}
end

# Start
{:ok, _} = Application.ensure_all_started(:briefly)

# Benchmark run

Benchee.run(
  %{
    "sum_utxos_without_snapshot" => fn {_dir, db_ref} ->
      {:ok, utxos} = OMG.DB.RocksDB.Core.decode_values(OMG.DB.RocksDB.Core.filter_keys(db_ref, :utxo))
    end,
    "sum_utxos_with_snapshot" => fn {_dir, db_ref} ->
      {:ok, utxos} = OMG.DB.RocksDB.Core.decode_values(OMG.DB.RocksDB.Core.filter_keys(db_ref, :utxo))
    end
  },
  inputs: %{
    "1000 utxos" => 1000,
    "10000 utxos" => 10_000
  },
  before_scenario: fn num_utxos ->
    {:ok, dir} = setup_db_with_data.(num_utxos)

    setup = [{:create_if_missing, false}, {:prefix_extractor, {:fixed_prefix_transform, 5}}]
    {:ok, db_ref} = :rocksdb.open(String.to_charlist(dir), setup)
    {dir, db_ref}
  end,
  after_scenario: fn {dir, db_ref} ->
    :ok = :rocksdb.close(db_ref)
    {:ok, _} = File.rm_rf(dir)
  end,
  time: 60,
  memory_time: 10
)
