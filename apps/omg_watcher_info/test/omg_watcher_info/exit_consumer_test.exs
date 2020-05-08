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

defmodule OMG.WatcherInfo.ExitConsumerTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures

  alias OMG.Crypto
  alias OMG.Utxo
  alias OMG.Utxo.Position
  alias OMG.WatcherInfo.DB
  alias OMG.WatcherInfo.ExitConsumer

  require Utxo

  setup_all do
    {:ok, _} =
      GenServer.start_link(
        ExitConsumer,
        [topic: :watcher_test_topic, bus_module: __MODULE__.FakeBus],
        name: TestExitConsumer
      )

    _ =
      on_exit(fn ->
        with pid when is_pid(pid) <- GenServer.whereis(TestExitConsumer) do
          :ok = GenServer.stop(TestExitConsumer)
        end
      end)
  end

  describe "ExitConsumer.handle_info/2" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "spending non-existing output does not break" do
      pos_1 = Position.encode(Utxo.position(5001, 0, 1))
      txhash = Crypto.hash(<<pos_1>>)

      event_data = [
        %{log_index: 2, root_chain_txhash: <<12::256>>, call_data: %{utxo_pos: pos_1}},
        %{log_index: 1, root_chain_txhash: <<11::256>>, call_data: %{txhash: txhash, oindex: 1}}
      ]

      send_events_and_wait_until_processed(event_data)

      assert_test_consumer_alive()
    end

    @tag fixtures: [:alice, :initial_blocks]
    test "when receive ife started or finalized events spends given outputs", %{alice: alice} do
      spent_utxos_pos = alice.addr |> get_utxos_pos() |> Enum.take(2)
      [pos_1, pos_2] = Enum.map(spent_utxos_pos, &Position.encode/1)

      # Note: event data is the same for InFlightExitStarted and InFlightExitOutputWithdrawn events
      event_data = [
        %{log_index: 2, root_chain_txhash: <<12::256>>, call_data: %{utxo_pos: pos_2}},
        %{log_index: 1, root_chain_txhash: <<11::256>>, call_data: %{utxo_pos: pos_1}}
      ]

      send_events_and_wait_until_processed(event_data)

      assert alice.addr |> get_utxos_pos() |> none_in(spent_utxos_pos)
    end

    @tag fixtures: [:alice, :initial_blocks]
    test "when receive IFE output piggybacked event spends this output", %{alice: alice} do
      %{creating_txhash: txhash, oindex: oindex} = output = alice.addr |> get_utxos_for() |> hd()
      spent_utxos_pos = get_utxos_pos([output])

      event_data = [
        %{log_index: 2, root_chain_txhash: <<12::256>>, call_data: %{txhash: txhash, oindex: oindex}}
      ]

      send_events_and_wait_until_processed(event_data)

      assert alice.addr |> get_utxos_pos() |> none_in(spent_utxos_pos)
    end

    @tag fixtures: [:alice, :initial_blocks]
    test "spending output more than once does not overwrite first event", %{alice: alice} do
      %{creating_txhash: txhash, oindex: oindex} = output = alice.addr |> get_utxos_for() |> hd()
      txo_pos = get_utxos_pos([output]) |> hd()

      expected_log_index = 1
      expected_root_hash = <<1::256>>

      send_events_and_wait_until_processed([
        %{
          log_index: expected_log_index,
          root_chain_txhash: expected_root_hash,
          call_data: %{txhash: txhash, oindex: oindex}
        }
      ])

      assert %DB.TxOutput{
               ethevents: [%DB.EthEvent{log_index: ^expected_log_index, root_chain_txhash: ^expected_root_hash}]
             } = DB.TxOutput.get_by_position(txo_pos)

      event_data_2 = [
        %{log_index: 2, root_chain_txhash: <<12::256>>, call_data: %{utxo_pos: Position.encode(txo_pos)}}
      ]

      send_events_and_wait_until_processed(event_data_2)

      assert %DB.TxOutput{
               ethevents: [%DB.EthEvent{log_index: ^expected_log_index, root_chain_txhash: ^expected_root_hash}]
             } = DB.TxOutput.get_by_position(txo_pos)
    end

    defp get_utxos_for(address) do
      [address: address]
      |> DB.TxOutput.get_utxos()
      |> Map.get(:data)
    end

    defp get_utxos_pos(<<_::160>> = address) do
      address
      |> get_utxos_for()
      |> get_utxos_pos()
    end

    defp get_utxos_pos(outputs) when is_list(outputs) do
      Enum.map(outputs, fn %{blknum: blknum, txindex: txindex, oindex: oindex} ->
        Utxo.position(blknum, txindex, oindex)
      end)
    end

    defp none_in(address_utxos, pos_to_check) do
      Enum.all?(pos_to_check, &(&1 not in address_utxos))
    end

    defp send_events_and_wait_until_processed(data) do
      pid = assert_test_consumer_alive()

      Process.send(pid, {:internal_event_bus, :data, data}, [:noconnect])

      # this waits for all messages in process inbox is processed
      _ = :sys.get_state(pid)
    end

    defp assert_test_consumer_alive() do
      pid = GenServer.whereis(TestExitConsumer)
      assert is_pid(pid) and Process.alive?(pid)
      pid
    end
  end

  defmodule FakeBus do
    def subscribe(_topic, _args), do: :ok
  end
end
