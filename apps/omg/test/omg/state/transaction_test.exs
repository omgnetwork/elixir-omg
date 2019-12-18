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

defmodule OMG.State.TransactionTest do
  @moduledoc """
  This test the public-most APIs regarging the transaction, being mainly centered around:
    - creation and encoding of raw transactions
    - some basic checks of internal APIs used elsewhere - getting inputs/outputs, spend authorization, hashing, encoding
  """
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.State.Transaction
  alias OMG.Utxo

  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @payment_output_type OMG.WireFormatTypes.output_type_for(:output_payment_v1)
  @utxo_positions [{20, 42, 1}, {2, 21, 0}, {1000, 0, 0}, {10_001, 0, 0}]
  @transaction Transaction.Payment.new(
                 [{1, 1, 0}, {1, 2, 1}],
                 [{"alicealicealicealice", @eth, 1}, {"carolcarolcarolcarol", @eth, 2}],
                 <<0::256>>
               )

  test "create transaction with metadata" do
    tx_with_metadata = Transaction.Payment.new(@utxo_positions, [{"Joe Black", @eth, 53}], <<0::256>>)
    tx_without_metadata = Transaction.Payment.new(@utxo_positions, [{"Joe Black", @eth, 53}])

    assert Transaction.raw_txhash(tx_with_metadata) == Transaction.raw_txhash(tx_without_metadata)

    assert byte_size(Transaction.raw_txbytes(tx_with_metadata)) ==
             byte_size(Transaction.raw_txbytes(tx_without_metadata))
  end

  test "raw transaction hash is invariant" do
    assert <<21, 94, 181, 22, 125, 2, 47, 124, 113>> <> _ = Transaction.raw_txhash(@transaction)
  end

  test "create transaction with different number inputs and outputs" do
    check_input1 = Utxo.position(20, 42, 1)
    output1 = {"Joe Black", @eth, 99}
    check_output2 = %{amount: 99, currency: @eth, owner: "Joe Black", output_type: @payment_output_type}
    # 1 - input, 1 - output
    tx1_1 = Transaction.Payment.new([hd(@utxo_positions)], [output1])
    assert 1 == tx1_1 |> Transaction.get_inputs() |> length()
    assert 1 == tx1_1 |> Transaction.get_outputs() |> length()
    assert [^check_input1 | _] = Transaction.get_inputs(tx1_1)
    assert ^check_output2 = Transaction.get_outputs(tx1_1) |> hd() |> Map.from_struct()
    # 4 - input, 4 - outputs
    tx4_4 = Transaction.Payment.new(@utxo_positions, [output1, {"J", @eth, 929}, {"J", @eth, 929}, {"J", @eth, 199}])
    assert 4 == tx4_4 |> Transaction.get_inputs() |> length()
    assert 4 == tx4_4 |> Transaction.get_outputs() |> length()
    assert [^check_input1 | _] = Transaction.get_inputs(tx4_4)
    assert ^check_output2 = Transaction.get_outputs(tx4_4) |> hd() |> Map.from_struct()
  end

  test "Decode raw transaction, a low level encode/decode parity check" do
    {:ok, decoded} = @transaction |> Transaction.raw_txbytes() |> Transaction.decode()
    assert decoded == @transaction
    assert decoded == @transaction |> Transaction.raw_txbytes() |> Transaction.decode!()
  end
end
