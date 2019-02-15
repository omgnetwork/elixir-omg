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

defmodule OMG.API.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.API.Core
  alias OMG.API.Crypto
  alias OMG.API.State.Transaction
  alias OMG.API.TestHelper

  @empty_signature <<0::size(520)>>
  @no_owner %{priv: <<>>, addr: nil}

  def eth, do: Crypto.zero_address()

  @tag fixtures: [:alice, :bob]
  test "signed transaction is valid in all input zeroing combinations", %{
    alice: alice,
    bob: bob
  } do
    [
      {[{1, 2, 3, alice}, {2, 3, 4, bob}], [{alice, eth(), 7}, {bob, eth(), 3}]},
      {[{1, 2, 3, alice}, {0, 0, 0, @no_owner}], [{alice, eth(), 7}, {bob, eth(), 3}]},
      {[{0, 0, 0, @no_owner}, {2, 3, 4, bob}], [{alice, eth(), 7}, {bob, eth(), 3}]}
    ]
    |> Enum.map(&parametrized_tester/1)
  end

  test "encoded transaction is malformed or empty" do
    assert {:error, :malformed_transaction} = Core.recover_tx(<<192>>)
    assert {:error, :malformed_transaction} = Core.recover_tx(<<0x80>>)
    assert {:error, :malformed_transaction} = Core.recover_tx(<<>>)
  end

  @tag fixtures: [:alice, :bob]
  test "encoded transaction is corrupt", %{alice: alice, bob: bob} do
    encoded_signed_tx = TestHelper.create_encoded([{1, 2, 3, alice}, {2, 3, 4, bob}], eth(), [{alice, 7}])
    cropped_size = byte_size(encoded_signed_tx) - 1

    malformed1 = encoded_signed_tx <> "a"
    malformed2 = "A" <> encoded_signed_tx
    <<_, malformed3::binary>> = encoded_signed_tx
    <<malformed4::binary-size(cropped_size), _::binary-size(1)>> = encoded_signed_tx

    assert {:error, :malformed_transaction} = Core.recover_tx(malformed1)
    assert {:error, :malformed_transaction_rlp} = Core.recover_tx(malformed2)
    assert {:error, :malformed_transaction_rlp} = Core.recover_tx(malformed3)
    assert {:error, :malformed_transaction_rlp} = Core.recover_tx(malformed4)
  end

  @tag fixtures: [:alice, :bob]
  test "address in encoded transaction malformed", %{alice: alice, bob: bob} do
    malformed_alice = %{addr: "0x0000000000000000000000000000000000000000"}
    malformed_eth = "0x0000000000000000000000000000000000000000"
    malformed_signed1 = TestHelper.create_signed([{1, 2, 3, alice}, {2, 3, 4, bob}], eth(), [{malformed_alice, 7}])
    malformed_signed2 = TestHelper.create_signed([{1, 2, 3, alice}, {2, 3, 4, bob}], malformed_eth, [{alice, 7}])

    malformed_signed3 =
      TestHelper.create_signed([{1, 2, 3, alice}, {2, 3, 4, bob}], eth(), [{alice, 7}, {malformed_alice, 3}])

    malformed1 = Transaction.Signed.encode(malformed_signed1)
    malformed2 = Transaction.Signed.encode(malformed_signed2)
    malformed3 = Transaction.Signed.encode(malformed_signed3)

    assert {:error, :malformed_address} = Core.recover_tx(malformed1)
    assert {:error, :malformed_address} = Core.recover_tx(malformed2)
    assert {:error, :malformed_address} = Core.recover_tx(malformed3)
  end

  @tag fixtures: [:alice]
  test "transaction must have distinct inputs", %{alice: alice} do
    duplicate_inputs = TestHelper.create_encoded([{1, 2, 3, alice}, {1, 2, 3, alice}], eth(), [{alice, 7}])

    assert {:error, :duplicate_inputs} = Core.recover_tx(duplicate_inputs)
  end

  @tag fixtures: [:alice, :bob]
  test "transaction is not allowed to have input and empty sigs", %{alice: alice} do
    tx = TestHelper.create_signed([{1, 2, 3, alice}, {2, 3, 4, alice}], eth(), [{alice, 7}])
    tx_no_sigs = %{tx | sigs: [@empty_signature, @empty_signature]}
    tx_hash = Transaction.Signed.encode(tx_no_sigs)
    assert {:error, :missing_signature} == Core.recover_tx(tx_hash)
  end

  @tag fixtures: [:alice]
  test "transactions with corrupt signatures don't do harm", %{alice: alice} do
    full_signed_tx = TestHelper.create_signed([{1, 2, 3, alice}], eth(), [{alice, 7}])
    %Transaction.Signed{sigs: [sig1 | _]} = full_signed_tx

    corrupt =
      %Transaction.Signed{full_signed_tx | sigs: [<<1::size(520)>>, sig1]}
      |> Transaction.Signed.encode()

    assert {:error, :signature_corrupt} == Core.recover_tx(corrupt)
  end

  @tag fixtures: [:alice]
  test "transaction is never allowed to have 2 empty inputs", %{alice: alice} do
    double_zero_tx1 =
      TestHelper.create_encoded([{0, 0, 0, %{priv: <<>>}}, {0, 0, 0, %{priv: <<>>}}], eth(), [{alice, 7}])

    double_zero_tx2 = TestHelper.create_encoded([{0, 0, 0, alice}, {0, 0, 0, alice}], eth(), [{alice, 7}])

    double_zero_tx3 =
      TestHelper.create_encoded([{0, 0, 0, %{priv: <<>>}}, {0, 0, 0, %{priv: <<>>}}], eth(), [{alice, 7}])

    double_zero_tx4 = TestHelper.create_encoded([{0, 0, 0, alice}, {0, 0, 0, alice}], eth(), [{alice, 7}])

    assert {:error, :no_inputs} == Core.recover_tx(double_zero_tx1)
    assert {:error, :no_inputs} == Core.recover_tx(double_zero_tx2)
    assert {:error, :no_inputs} == Core.recover_tx(double_zero_tx3)
    assert {:error, :no_inputs} == Core.recover_tx(double_zero_tx4)
  end

  @tag fixtures: [:alice, :bob]
  test "transaction with 4in/4out is valid", %{alice: alice, bob: bob} do
    [
      {[{1, 2, 3, alice}, {2, 3, 1, alice}, {2, 3, 2, bob}, {3, 3, 4, bob}],
       [{alice, eth(), 7}, {alice, eth(), 3}, {bob, eth(), 7}, {bob, eth(), 3}]}
    ]
    |> Enum.map(&parametrized_tester/1)
  end

  @tag fixtures: [:alice, :bob]
  test "transaction without exactly 4 inputs or exactly 4 outputs returns malformed_transaction", %{alice: alice, bob: bob} do

    inputs =   [{1, 2, 3, alice}, {2, 3, 1, alice}]

    tx_inputs =
      inputs
      |> Enum.map(fn {blknum, txindex, oindex, _} -> %{blknum: blknum, txindex: txindex, oindex: oindex} end)

    tx_outputs =
      [{alice, eth(), 7}, {alice, eth(), 3}]
      |> Enum.map(fn {owner, currency, amount} -> %{owner: owner.addr, currency: currency, amount: amount} end)

    raw_tx = %Transaction{inputs: tx_inputs, outputs: tx_outputs}


    priv_keys =  inputs |> Enum.map(fn {_, _, _, owner} -> owner.priv end)
    tx = Transaction.sign(raw_tx, priv_keys)
    encoded_signed_tx = Transaction.Signed.encode(tx)

    IO.inspect Core.recover_tx(encoded_signed_tx)
    spenders =
      inputs
      |> Enum.map(fn {_, _, _, spender} -> spender.addr end)

    assert {:ok,
             %Transaction.Recovered{
               signed_tx: ^tx,
               spenders: ^spenders
             }} = Core.recover_tx(encoded_signed_tx)

  end

  defp parametrized_tester({inputs, outputs}) do
    tx = TestHelper.create_signed(inputs, outputs)

    encoded_signed_tx = Transaction.Signed.encode(tx)

    spenders =
      inputs
      |> Enum.filter(fn {_, _, _, %{addr: addr}} -> addr != nil end)
      |> Enum.map(fn {_, _, _, spender} -> spender.addr end)

    assert {:ok,
            %Transaction.Recovered{
              signed_tx: ^tx,
              spenders: ^spenders
            }} = Core.recover_tx(encoded_signed_tx)
  end
end
