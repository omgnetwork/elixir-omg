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

defmodule OMG.Watcher.API.InFlightsTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias OMG.API
  alias OMG.API.Crypto
  alias OMG.API.State.Transaction
  alias OMG.Watcher

  @eth Crypto.zero_address()

  @tag fixtures: [:initial_blocks, :bob]
  test "prepares the IFE info - 1 input", %{initial_blocks: initial_blocks, bob: bob} do
    [compare_in_tx1] = get_compare_in_txs(initial_blocks, [{3000, 1}])

    # see initial_blocks, we're combining two outputs from those transactions
    %Transaction.Recovered{signed_tx: %Transaction.Signed{signed_tx_bytes: signed_tx_bytes}} =
      API.TestHelper.create_recovered([{3000, 1, 0, bob}], @eth, [{bob, 150}])

    assert {:ok,
            %{
              # checking just lengths in majority as we prepare verify correctness in the contract in integration tests
              # the byte size is hard-coded - how much does it bother us?
              in_flight_tx: <<_bytes::bytes-size(200)>>,
              input_txs: ^compare_in_tx1,
              # a non-encoded proof, 512 bytes each
              input_txs_inclusion_proofs: <<_proof::bytes-size(512)>>,
              # two non-encoded signatures, 65 bytes each, second one is zero-bytes, that's ok with contract
              in_flight_tx_sigs: <<_sigs::bytes-size(130)>>
            }} = Watcher.API.get_in_flight_exit(signed_tx_bytes)
  end

  @tag fixtures: [:initial_blocks, :alice, :bob]
  test "prepares the IFE info - 2 inputs", %{initial_blocks: initial_blocks, alice: alice, bob: bob} do
    [compare_in_tx1, compare_in_tx2] = get_compare_in_txs(initial_blocks, [{3000, 1}, {2000, 0}])

    # see initial_blocks, we're combining two outputs from those transactions
    %Transaction.Recovered{signed_tx: %Transaction.Signed{signed_tx_bytes: signed_tx_bytes}} =
      API.TestHelper.create_recovered([{3000, 1, 0, bob}, {2000, 0, 1, alice}], @eth, [{bob, 151}])

    compare_in_txs_bytes = compare_in_tx1 <> compare_in_tx2

    assert {:ok,
            %{
              # see 1 input case for comments
              in_flight_tx: <<_bytes::bytes-size(202)>>,
              input_txs: ^compare_in_txs_bytes,
              input_txs_inclusion_proofs: <<_proof::bytes-size(1024)>>,
              in_flight_tx_sigs: <<_sigs::bytes-size(130)>>
            }} = Watcher.API.get_in_flight_exit(signed_tx_bytes)
  end

  # gets the input transactions, as expected from the endpoint - based on the position and initial_blocks fixture
  defp get_compare_in_txs(initial_blocks, positions) do
    initial_blocks
    |> Enum.filter(fn {blknum, txindex, _, _} -> {blknum, txindex} in positions end)
    # reversing, because the inputs are reversed in the IFtx below, and we need that order, not by posiion!
    |> Enum.reverse()
    |> Enum.map(fn {_, _, _, %Transaction.Recovered{signed_tx: %Transaction.Signed{raw_tx: raw_tx}}} ->
      Transaction.encode(raw_tx)
    end)
  end

  @tag fixtures: [:phoenix_ecto_sandbox, :bob]
  test "behaves well if inputs not found", %{bob: bob} do
    %Transaction.Recovered{signed_tx: %Transaction.Signed{signed_tx_bytes: signed_tx_bytes}} =
      API.TestHelper.create_recovered([{3000, 1, 0, bob}], @eth, [{bob, 150}])

    assert {:error, :tx_for_input_not_found} = Watcher.API.get_in_flight_exit(signed_tx_bytes)
  end

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "behaves well if IFtx malformed; behavior from OMG.API.Core.recover_tx/1" do
    assert {:error, :malformed_transaction} = Watcher.API.get_in_flight_exit("")
  end
end
