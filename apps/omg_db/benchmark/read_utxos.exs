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
# Usage: mix run apps/omg_db/benchmark/read_utxos.exs
#

defmodule OMG.DB.Benchmark.Helper do
  @moduledoc false

  def populate_utxos(server_pid, num_utxos) do
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
    |> OMG.DB.multi_update(server_pid)
  end

  defp random_bytes() do
    0..255 |> Enum.shuffle() |> :erlang.list_to_binary()
  end
end

alias OMG.DB.Benchmark.Helper

:ok = Logger.configure(level: :warn)
{:ok, _} = Application.ensure_all_started(:briefly)

Benchee.run(
  %{
    "OMG.DB.utxos" => fn {_dir, server_pid} ->
      {:ok, _utxos} = OMG.DB.utxos(server_pid)
    end
  },
  inputs: %{
    "1,000 utxos" => 1000,
    "10,000 utxos" => 10_000,
    "100,000 utxos" => 100_000
  },
  before_scenario: fn num_utxos ->
    {:ok, dir} = Briefly.create(directory: true)
    :ok = OMG.DB.RocksDB.Server.init_storage(dir)
    {:ok, server_pid} = GenServer.start_link(OMG.DB.RocksDB.Server, [db_path: dir, name: :benchmark_db])

    :ok = Helper.populate_utxos(server_pid, num_utxos)

    {dir, server_pid}
  end,
  after_scenario: fn {dir, server_pid} ->
    true = Process.exit(server_pid, :shutdown)
    {:ok, _} = File.rm_rf(dir)
  end,
  time: 10,
  memory_time: 2
)
