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

defmodule OMG.DB.MonitorTest do
  use ExUnit.Case, async: true

  alias __MODULE__.MockDB
  alias OMG.DB.Monitor

  test "calculates and emits telemetry on start" do
    _ = attach([:balances, Monitor])
    _ = attach([:total_unspent_addresses, Monitor])
    _ = attach([:total_unspent_outputs, Monitor])

    {:ok, _pid} = Monitor.start_link(db_module: MockDB, check_interval_ms: 999_999_999)
    assert_receive({:telemetry_event, [:balances, Monitor], %{balances: _}, _})
    assert_receive({:telemetry_event, [:total_unspent_addresses, Monitor], %{total_unspent_addresses: _}, _})
    assert_receive({:telemetry_event, [:total_unspent_outputs, Monitor], %{total_unspent_outputs: _}, _})
  end

  test "calculates and emits telemetry after check_interval_ms" do
    _ = attach([:balances, Monitor])
    _ = attach([:total_unspent_addresses, Monitor])
    _ = attach([:total_unspent_outputs, Monitor])

    {:ok, _pid} = Monitor.start_link(db_module: MockDB, check_interval_ms: 2000)
    :ok = Process.sleep(1500)

    assert_receive({:telemetry_event, [:balances, Monitor], %{balances: _}, _})
    assert_receive({:telemetry_event, [:total_unspent_addresses, Monitor], %{total_unspent_addresses: _}, _})
    assert_receive({:telemetry_event, [:total_unspent_outputs, Monitor], %{total_unspent_outputs: _}, _})
  end

  defp attach(event) do
    listener = self()
    handler_id = {__MODULE__, :rand.uniform(100)}

    :ok =
      :telemetry.attach(
        handler_id,
        event,
        fn received_event, measurements, metadata, _ ->
          send(listener, {:telemetry_event, received_event, measurements, metadata})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  defmodule MockDB do
    @moduledoc """
    Mocks `OMG.DB` for testing.
    """
    require OMG.Utxo
    alias OMG.TestHelper
    alias OMG.Utxo

    # Mocks `OMG.DB.utxos/0`
    def utxos() do
      utxos = %{
        Utxo.position(2_000, 4076, 3) => %OMG.Utxo{
          output: %OMG.Output{
            amount: 700_000_000,
            currency: OMG.Eth.zero_address(),
            owner: TestHelper.generate_entity()
          }
        }
      }

      {:ok, utxos}
    end
  end
end
