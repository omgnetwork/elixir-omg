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

defmodule OMG.WatcherRPC.Web.Controller.InFlightExitTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures
  use OMG.Watcher.Fixtures

  alias OMG.State.Transaction
  alias OMG.Utils.HttpRPC.Encoding
  alias Support.WatcherHelper
  @eth OMG.Eth.RootChain.eth_pseudo_address()

  describe "getting in-flight exits" do
    @tag fixtures: [:web_endpoint, :db_initialized, :bob, :alice]
    test "returns properly formatted in-flight exit data", %{bob: bob, alice: alice} do
      test_in_flight_exit_data = fn inputs, expected_input_txs ->
        in_flight_txbytes =
          inputs
          |> OMG.TestHelper.create_encoded(@eth, [{bob, 100}])
          |> Encoding.to_hex()

        # `2 + ` for prepending `0x` in HEX encoded binaries
        proofs_size = 2 + 1024 * length(inputs)
        sigs_size = 2 + 130 * length(inputs)

        # checking just lengths in majority as we prepare verify correctness in the contract in integration tests
        assert %{
                 "in_flight_tx" => _in_flight_tx,
                 "input_txs" => input_txs,
                 # encoded proofs, 1024 bytes each
                 "input_txs_inclusion_proofs" => <<_proof::bytes-size(proofs_size)>>,
                 # encoded signatures, 130 bytes each
                 "in_flight_tx_sigs" => <<_bytes::bytes-size(sigs_size)>>
               } = TestHelper.success?("/in_flight_exit.get_data", %{"txbytes" => in_flight_txbytes})

        {:ok, input_txs} = Encoding.from_hex(input_txs)

        input_txs =
          input_txs
          |> ExRLP.decode()
          |> Enum.filter(&(&1 != ""))
          |> Enum.map(&ExRLP.encode/1)
          |> Enum.map(&Transaction.decode!/1)

        assert input_txs == expected_input_txs
      end

      OMG.DB.multi_update(
        [
          [
            OMG.TestHelper.create_encoded([{1, 0, 0, alice}], @eth, [{bob, 300}]),
            OMG.TestHelper.create_encoded([{1000, 0, 0, bob}], @eth, [{alice, 100}, {bob, 200}])
          ],
          [OMG.TestHelper.create_encoded([{1000, 1, 0, alice}], @eth, [{bob, 99}, {alice, 1}], <<1322::256>>)],
          [
            OMG.TestHelper.create_encoded([], @eth, [{alice, 150}]),
            OMG.TestHelper.create_encoded([{1000, 1, 1, bob}], @eth, [{bob, 150}, {alice, 50}])
          ]
        ]
        |> Enum.with_index(1)
        |> Enum.map(fn {transactions, index} ->
          {:put, :block, %{hash: <<index>>, number: index * 1000, transactions: transactions}}
        end)
      )

      test_in_flight_exit_data.([{3000, 1, 0, alice}], [
        Transaction.Payment.new([{1000, 1, 1}], [{bob.addr, @eth, 150}, {alice.addr, @eth, 50}])
      ])

      test_in_flight_exit_data.([{3000, 1, 0, alice}, {2000, 0, 1, alice}], [
        Transaction.Payment.new([{1000, 1, 1}], [{bob.addr, @eth, 150}, {alice.addr, @eth, 50}]),
        Transaction.Payment.new([{1000, 1, 0}], [{bob.addr, @eth, 99}, {alice.addr, @eth, 1}], <<1322::256>>)
      ])
    end

    @tag fixtures: [:web_endpoint, :db_initialized, :bob]
    test "behaves well if input is not found", %{bob: bob} do
      in_flight_txbytes =
        [{3000, 1, 0, bob}]
        |> OMG.TestHelper.create_encoded(@eth, [{bob, 150}])
        |> Encoding.to_hex()

      assert %{
               "code" => "in_flight_exit:tx_for_input_not_found",
               "description" => "No transaction that created input."
             } = TestHelper.no_success?("/in_flight_exit.get_data", %{"txbytes" => in_flight_txbytes})
    end

    @tag fixtures: [:web_endpoint]
    test "behaves well if input malformed" do
      assert %{"code" => "get_in_flight_exit:malformed_transaction"} =
               TestHelper.no_success?("/in_flight_exit.get_data", %{"txbytes" => "0x00"})
    end

    @tag fixtures: [:web_endpoint]
    test "responds with error for malformed in-flight transaction bytes" do
      assert %{
               "code" => "operation:bad_request",
               "description" => "Parameters required by this operation are missing or incorrect.",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "txbytes",
                   "validator" => ":hex"
                 }
               }
             } = TestHelper.no_success?("/in_flight_exit.get_data", %{"txbytes" => "tx"})

      assert %{
               "code" => "get_in_flight_exit:malformed_transaction_rlp",
               "object" => "error"
             } = TestHelper.no_success?("/in_flight_exit.get_data", %{"txbytes" => "0x1234"})
    end
  end
end
