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

defmodule OMG.API.State.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.API
  alias OMG.API.DevCrypto
  alias OMG.API.State.{Core, Transaction}
  alias OMG.API.TestHelper

  @zero_address OMG.Eth.zero_address()

  deffixture transaction do
    Transaction.new(
      [{1, 1, 0}, {1, 2, 1}],
      [{"alicealicealicealice", eth(), 1}, {"carolcarolcarolcarol", eth(), 2}],
      <<0::256>>
    )
  end

  deffixture utxos do
    [{20, 42, 1}, {2, 21, 0}]
  end

  def eth, do: OMG.Eth.RootChain.eth_pseudo_address()

  @tag fixtures: [:transaction]
  test "transaction hash is correct", %{transaction: transaction} do
    {:ok, hash_value} = Base.decode16("09645ee9736332be55eaccf9d08ff572a6fa23e2f6dc2aac42dbf09832d8f60e", case: :lower)
    assert Transaction.hash(transaction) == hash_value
  end

  @tag fixtures: [:utxos]
  test "create transaction with different number inputs and oputputs", %{utxos: utxos} do
    # 1 - input, 1 - output
    assert Transaction.new([hd(utxos)], [{"Joe Black", eth(), 99}]) == %Transaction{
             inputs: [%{blknum: 20, txindex: 42, oindex: 1} | List.duplicate(%{blknum: 0, oindex: 0, txindex: 0}, 3)],
             outputs: [
               %{owner: "Joe Black", currency: eth(), amount: 99}
               | List.duplicate(%{owner: @zero_address, currency: eth(), amount: 0}, 3)
             ]
           }

    # 1 - input, 2 - outputs
    assert Transaction.new(tl(utxos), [{"Joe Black", eth(), 22}, {"McDuck", eth(), 21}]) == %Transaction{
             inputs: [%{blknum: 2, txindex: 21, oindex: 0} | List.duplicate(%{blknum: 0, txindex: 0, oindex: 0}, 3)],
             outputs: [
               %{owner: "Joe Black", currency: eth(), amount: 22},
               %{owner: "McDuck", currency: eth(), amount: 21}
               | List.duplicate(%{owner: @zero_address, currency: eth(), amount: 0}, 2)
             ]
           }

    # 2 - inputs, 2 - outputs
    assert Transaction.new(utxos, [{"Joe Black", eth(), 53}, {"McDuck", eth(), 90}]) == %Transaction{
             inputs: [
               %{blknum: 20, txindex: 42, oindex: 1},
               %{blknum: 2, txindex: 21, oindex: 0} | List.duplicate(%{blknum: 0, txindex: 0, oindex: 0}, 2)
             ],
             outputs: [
               %{owner: "Joe Black", currency: eth(), amount: 53},
               %{owner: "McDuck", currency: eth(), amount: 90}
               | List.duplicate(%{owner: @zero_address, currency: eth(), amount: 0}, 2)
             ]
           }

    # 2 - inputs, 0 - outputs
    assert Transaction.new(utxos, []) == %Transaction{
             inputs: [
               %{blknum: 20, txindex: 42, oindex: 1},
               %{blknum: 2, txindex: 21, oindex: 0} | List.duplicate(%{blknum: 0, txindex: 0, oindex: 0}, 2)
             ],
             outputs: List.duplicate(%{owner: @zero_address, currency: eth(), amount: 0}, 4)
           }
  end

  @tag fixtures: [:utxos]
  test "create transaction with metadata", %{utxos: utxos} do
    assert Transaction.new(utxos, [{"Joe Black", eth(), 53}], <<42::256>>) == %Transaction{
             inputs: [
               %{blknum: 20, txindex: 42, oindex: 1},
               %{blknum: 2, txindex: 21, oindex: 0} | List.duplicate(%{blknum: 0, txindex: 0, oindex: 0}, 2)
             ],
             outputs: [
               %{owner: "Joe Black", currency: eth(), amount: 53}
               | List.duplicate(%{owner: @zero_address, currency: eth(), amount: 0}, 3)
             ],
             metadata: <<42::256>>
           }
  end

  @tag fixtures: [:utxos]
  test "incorrect metadata", %{utxos: utxos} do
    # too long metadata
    assert_raise FunctionClauseError, fn ->
      Transaction.new(utxos, [%{owner: "Joe Black", currency: eth(), amount: 53}], String.duplicate("0", 90))
    end

    # incorrect type
    assert_raise FunctionClauseError, fn ->
      Transaction.new(utxos, [%{owner: "Joe Black", currency: eth(), amount: 53}], 42)
    end
  end

  @tag fixtures: [:alice, :state_alice_deposit, :bob]
  test "using created transaction in child chain", %{alice: alice, bob: bob, state_alice_deposit: state} do
    state =
      state
      |> TestHelper.do_deposit(alice, %{amount: 10, currency: eth(), blknum: 2})

    transaction = Transaction.new([{1, 0, 0}, {2, 0, 0}], [{bob.addr, eth(), 12}])

    transaction
    |> DevCrypto.sign([alice.priv, alice.priv])
    |> assert_tx_usable(state)
  end

  @tag fixtures: [:alice, :state_alice_deposit, :bob]
  test "using created transaction with one input in child chain", %{alice: alice, bob: bob, state_alice_deposit: state} do
    transaction = Transaction.new([{1, 0, 0}], [{bob.addr, eth(), 4}])

    transaction
    |> DevCrypto.sign([alice.priv, <<>>])
    |> assert_tx_usable(state)
  end

  defp assert_tx_usable(signed, state_core) do
    {:ok, transaction} = signed |> Transaction.Signed.encode() |> API.Core.recover_tx()

    assert {:ok, {_, _, _}, _state} = Core.exec(state_core, transaction, %{eth() => 0})
  end

  @tag fixtures: [:alice, :bob]
  test "different signers, one output", %{alice: alice, bob: bob} do
    tx =
      [{3000, 0, 0}, {3000, 0, 1}]
      |> Transaction.new([{alice.addr, eth(), 10}])
      |> DevCrypto.sign([bob.priv, alice.priv])
      |> Transaction.Signed.encode()

    {:ok, recovered} = tx |> OMG.API.Core.recover_tx()
    assert recovered.spenders == [bob.addr, alice.addr]
  end

  @tag fixtures: [:alice, :bob, :carol]
  test "checks if spenders are authorized", %{alice: alice, bob: bob, carol: carol} do
    authorized_tx = TestHelper.create_recovered([{1, 1, 0, alice}, {1, 3, 0, bob}], eth(), [{bob, 6}, {alice, 4}])

    :ok = Transaction.Recovered.all_spenders_authorized(authorized_tx, [alice.addr, bob.addr])

    {:error, :unauthorized_spent} = Transaction.Recovered.all_spenders_authorized(authorized_tx, [bob.addr, alice.addr])

    {:error, :unauthorized_spent} = Transaction.Recovered.all_spenders_authorized(authorized_tx, [carol.addr])

    {:error, :unauthorized_spent} =
      Transaction.Recovered.all_spenders_authorized(authorized_tx, [alice.addr, carol.addr])
  end

  @tag fixtures: [:transaction]
  test "Decode transaction", %{transaction: tx} do
    {:ok, decoded} = tx |> Transaction.encode() |> Transaction.decode()
    assert decoded == tx
  end

  @tag fixtures: [:alice]
  test "decoding malformed signed transaction", %{alice: alice} do
    %Transaction.Signed{sigs: sigs, raw_tx: raw_tx} =
      Transaction.new([{1, 0, 0}, {2, 0, 0}], [{alice.addr, eth(), 12}])
      |> DevCrypto.sign([alice.priv, alice.priv])

    [inputs, outputs] = Transaction.encode(raw_tx) |> ExRLP.decode()

    assert {:error, :malformed_transaction} = Transaction.Signed.decode(ExRLP.encode(23))
    assert {:error, :malformed_transaction} = Transaction.Signed.decode(ExRLP.encode([sigs, []]))

    assert {:error, :malformed_signatures} == Transaction.Signed.decode(ExRLP.encode([[<<1>>, <<1>>], inputs, outputs]))
    assert {:error, :malformed_signatures} == Transaction.Signed.decode(ExRLP.encode([<<1>>, inputs, outputs]))

    assert {:error, :malformed_inputs} = Transaction.Signed.decode(ExRLP.encode([sigs, 42, outputs]))
    assert {:error, :malformed_inputs} = Transaction.Signed.decode(ExRLP.encode([sigs, [[1, 2]], outputs]))
    assert {:error, :malformed_inputs} = Transaction.Signed.decode(ExRLP.encode([sigs, [[1, 2, 'a']], outputs]))

    assert {:error, :malformed_outputs} = Transaction.Signed.decode(ExRLP.encode([sigs, inputs, 42]))

    assert {:error, :malformed_outputs} =
             Transaction.Signed.decode(ExRLP.encode([sigs, inputs, [[alice.addr, alice.addr]]]))

    assert {:error, :malformed_outputs} =
             Transaction.Signed.decode(ExRLP.encode([sigs, inputs, [[alice.addr, alice.addr, 'a']]]))

    assert {:error, :malformed_metadata} = Transaction.Signed.decode(ExRLP.encode([sigs, inputs, outputs, ""]))
  end
end
