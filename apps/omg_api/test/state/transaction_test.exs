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
      [{"alicealicealicealice", eth(), 1}, {"carolcarolcarolcarol", eth(), 2}]
    )
  end

  deffixture utxos do
    [{20, 42, 1}, {2, 21, 0}]
  end

  def eth, do: OMG.Eth.RootChain.eth_pseudo_address()

  @tag fixtures: [:transaction]
  test "transaction hash is correct", %{transaction: transaction} do
    {:ok, hash_value} = Base.decode16("e0e6fbd41f4909b4e621565fcdf6a0b54921711ff15a23d6cb07f1f87e345a33", case: :lower)
    assert Transaction.hash(transaction) == hash_value
  end

  @tag fixtures: [:utxos]
  test "create transaction with different number inputs and oputputs", %{utxos: utxos} do
    # 1 - input, 1 - output
    transaction = Transaction.new([hd(utxos)], [{"Joe Black", eth(), 99}])

    assert transaction == %Transaction{
             inputs: [%{blknum: 20, txindex: 42, oindex: 1} | List.duplicate(%{blknum: 0, oindex: 0, txindex: 0}, 3)],
             outputs: [
               %{owner: "Joe Black", currency: eth(), amount: 99}
               | List.duplicate(%{owner: @zero_address, currency: eth(), amount: 0}, 3)
             ]
           }

    # 1 - input, 2 - outputs
    transaction = Transaction.new(tl(utxos), [{"Joe Black", eth(), 22}, {"McDuck", eth(), 21}])

    assert transaction == %Transaction{
             inputs: [%{blknum: 2, txindex: 21, oindex: 0} | List.duplicate(%{blknum: 0, txindex: 0, oindex: 0}, 3)],
             outputs: [
               %{owner: "Joe Black", currency: eth(), amount: 22},
               %{owner: "McDuck", currency: eth(), amount: 21}
               | List.duplicate(%{owner: @zero_address, currency: eth(), amount: 0}, 2)
             ]
           }

    # 2 - inputs, 2 - outputs
    transaction = Transaction.new(utxos, [{"Joe Black", eth(), 53}, {"McDuck", eth(), 90}])

    assert transaction == %Transaction{
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
    transaction = Transaction.new(utxos, [])

    assert transaction == %Transaction{
             inputs: [
               %{blknum: 20, txindex: 42, oindex: 1},
               %{blknum: 2, txindex: 21, oindex: 0} | List.duplicate(%{blknum: 0, txindex: 0, oindex: 0}, 2)
             ],
             outputs: List.duplicate(%{owner: @zero_address, currency: eth(), amount: 0}, 4)
           }
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
  test "decoding signed transaction fails when signatures do not have a proper length", %{alice: alice} do
    tx = Transaction.new([{1000, 0, 0}, {1000, 0, 1}], [{alice.addr, eth(), 10}])

    [inputs, outputs] =
      tx
      |> Transaction.encode()
      |> ExRLP.decode()

    encoded_with_sigs = ExRLP.encode([[<<1>>, <<1>>], inputs, outputs])

    assert {:error, :bad_signature_length} == Transaction.Signed.decode(encoded_with_sigs)
  end
end
