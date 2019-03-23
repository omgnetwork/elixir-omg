# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.Watcher.Web.Controller.InFlightExitTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures

  alias OMG.RPC.Web.Encoding
  alias OMG.State.Transaction
  alias OMG.Watcher.TestHelper

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  describe "getting in-flight exits" do
    @tag fixtures: [:initial_blocks, :bob, :alice]
    test "returns properly formatted in-flight exit data", %{initial_blocks: initial_blocks, bob: bob, alice: alice} do
      test_in_flight_exit_data = fn inputs ->
        positions = Enum.map(inputs, fn {blknum, txindex, _, _} -> {blknum, txindex} end)

        expected_input_txs = get_input_txs(initial_blocks, positions)

        in_flight_txbytes =
          inputs
          |> OMG.TestHelper.create_encoded(@eth, [{bob, 100}])
          |> Encoding.to_hex()

        # `2 + ` for prepending `0x` in HEX encoded binaries
        proofs_size = 2 + 1024 * length(inputs)
        sigs_size = 2 + 130 * 4

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
          |> Enum.map(fn
            "" ->
              nil

            rlp_decoded ->
              {:ok, tx} = Transaction.reconstruct(rlp_decoded)
              tx
          end)

        assert input_txs == expected_input_txs
      end

      test_in_flight_exit_data.([{3000, 1, 0, alice}])
      test_in_flight_exit_data.([{3000, 1, 0, alice}, {2000, 0, 1, alice}])
    end

    # gets the input transactions, as expected from the endpoint - based on the position and initial_blocks fixture
    defp get_input_txs(initial_blocks, positions) do
      filler = List.duplicate(nil, 4 - length(positions))

      initial_blocks
      |> Enum.filter(fn {blknum, txindex, _, _} -> {blknum, txindex} in positions end)
      # reversing, because the inputs are reversed in the IFtx below, and we need that order, not by position!
      |> Enum.reverse()
      |> Enum.map(fn {_, _, _, %Transaction.Recovered{signed_tx: %Transaction.Signed{raw_tx: raw_tx}}} -> raw_tx end)
      |> Enum.concat(filler)
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :bob]
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

    @tag fixtures: [:phoenix_ecto_sandbox]
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
    end
  end
end
