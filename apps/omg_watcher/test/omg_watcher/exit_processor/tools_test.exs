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

defmodule OMG.Watcher.ExitProcessor.ToolsTest do
  @moduledoc """
  Test of the logic of exit processor - various generic tests: starting events, some sanity checks, ife listing
  """
  use OMG.Watcher.ExitProcessor.Case, async: true

  alias OMG.Utxo
  alias OMG.Watcher.ExitProcessor.Tools

  require Utxo

  describe "to_bus_events/1" do
    setup _ do
      {:ok,
       %{
         finalizations: [
           %{in_flight_exit_id: <<1::192>>, log_index: 1, root_chain_txhash: <<1::256>>},
           %{in_flight_exit_id: <<2::192>>, log_index: 2, root_chain_txhash: <<2::256>>}
         ],
         start_ife_events: [
           %{log_index: 1, root_chain_txhash: <<11::256>>, tx_hash: <<255::256>>, eth_height: 110},
           %{log_index: 2, root_chain_txhash: <<12::256>>, tx_hash: <<255::256>>, eth_height: 111}
         ],
         piggyback_output_events: [
           %{log_index: 1, root_chain_txhash: <<11::256>>, tx_hash: <<255::256>>, eth_height: 210, output_index: 1},
           %{log_index: 2, root_chain_txhash: <<12::256>>, tx_hash: <<255::256>>, eth_height: 210, output_index: 0}
         ],
         utxos: [
           Utxo.position(1, 0, 0),
           Utxo.position(1000, 0, 0),
           Utxo.position(2000, 0, 0)
         ]
       }}
    end

    test "mapping single finalization", %{finalizations: [f1 | _], utxos: [utxo_1 | _]} do
      utxo_pos = Utxo.Position.encode(utxo_1)

      assert [
               %{log_index: 1, root_chain_txhash: <<1::256>>, call_data: %{utxo_pos: ^utxo_pos}}
             ] = Tools.to_bus_events_data([{f1, [utxo_1]}])
    end

    test "mapping multiple finalizations", %{finalizations: [f1, f2 | _], utxos: utxos} do
      [utxo_1, utxo_2, utxo_3 | _] = utxos
      [utxo_pos_1, utxo_pos_2, utxo_pos_3 | _] = Enum.map(utxos, &Utxo.Position.encode/1)

      assert [
               %{log_index: 2, root_chain_txhash: <<2::256>>, call_data: %{utxo_pos: ^utxo_pos_2}},
               %{log_index: 2, root_chain_txhash: <<2::256>>, call_data: %{utxo_pos: ^utxo_pos_3}},
               %{log_index: 1, root_chain_txhash: <<1::256>>, call_data: %{utxo_pos: ^utxo_pos_1}}
             ] = Tools.to_bus_events_data([{f1, [utxo_1]}, {f2, [utxo_2, utxo_3]}])
    end

    test "finalization without exiting utxos does not produce events",
         %{finalizations: [f1, f2 | _], utxos: [utxo_1 | _]} do
      utxo_pos = Utxo.Position.encode(utxo_1)

      assert [
               %{log_index: 2, root_chain_txhash: <<2::256>>, call_data: %{utxo_pos: ^utxo_pos}}
             ] = Tools.to_bus_events_data([{f1, []}, {f2, [utxo_1]}])
    end

    test "empty finalization list does not produce events" do
      assert [] = Tools.to_bus_events_data([])
    end

    test "mapping in_flight_exit_started events", %{start_ife_events: [s1, s2 | _], utxos: utxos} do
      [utxo_pos_1, utxo_pos_2, utxo_pos_3] =
        encoded_utxos =
        utxos
        |> Enum.map(&Utxo.Position.encode/1)
        |> Enum.take(3)

      events_with_utxos = [
        {s1, Enum.take(encoded_utxos, 2)},
        {s2, Enum.drop(encoded_utxos, 2)}
      ]

      assert [
               %{log_index: 2, root_chain_txhash: <<12::256>>, call_data: %{utxo_pos: ^utxo_pos_3}},
               %{log_index: 1, root_chain_txhash: <<11::256>>, call_data: %{utxo_pos: ^utxo_pos_1}},
               %{log_index: 1, root_chain_txhash: <<11::256>>, call_data: %{utxo_pos: ^utxo_pos_2}}
             ] = Tools.to_bus_events_data(events_with_utxos)
    end
  end
end
