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
  alias OMG.API.Crypto
  alias OMG.API.State.{Core, Transaction}
  alias OMG.API.TestHelper

  @signature <<1>> |> List.duplicate(65) |> :binary.list_to_bin()

  deffixture transaction do
    %Transaction{
      blknum1: 1,
      txindex1: 1,
      oindex1: 0,
      blknum2: 1,
      txindex2: 2,
      oindex2: 1,
      cur12: eth(),
      newowner1: "alicealicealicealice",
      amount1: 1,
      newowner2: "carolcarolcarolcarol",
      amount2: 2
    }
  end

  deffixture utxos do
    %{
      address: "McDuck",
      utxos: [
        %{
          amount: 100,
          blknum: 20,
          oindex: 1,
          currency: eth(),
          txbytes: "not important",
          txindex: 42
        },
        %{
          amount: 43,
          blknum: 2,
          oindex: 0,
          currency: eth(),
          txbytes: "ble ble bla",
          txindex: 21
        }
      ]
    }
  end

  def eth, do: Crypto.zero_address()

  @tag fixtures: [:transaction]
  test "transaction hash is correct", %{transaction: transaction} do
    {:ok, hash_value} = Base.decode16("f09d08d506a269f4237f712a7cdc8259489f0435b0775b4e08050523788268a8", case: :lower)
    assert Transaction.hash(transaction) == hash_value
  end

  @tag fixtures: [:transaction]
  test "signed transaction hash is correct", %{transaction: transaction} do
    signed = %Transaction.Signed{raw_tx: transaction, sig1: @signature, sig2: @signature}
    {:ok, expected} = Base.decode16("61c4551565f6beefd2e9129f3dc104e6d53e9862c2775de41cd20029a6037181", case: :lower)
    actual = Transaction.Signed.signed_hash(signed)
    assert actual == expected
  end

  @tag fixtures: [:utxos]
  test "crete transaction", %{utxos: utxos} do
    {:ok, transaction} = Transaction.create_from_utxos(utxos, %{address: "Joe Black", amount: 53})

    assert transaction == %Transaction{
             blknum1: 20,
             txindex1: 42,
             oindex1: 1,
             blknum2: 2,
             txindex2: 21,
             oindex2: 0,
             cur12: eth(),
             newowner1: "Joe Black",
             amount1: 53,
             newowner2: "McDuck",
             amount2: 90
           }
  end

  @tag fixtures: [:utxos]
  test "checking error messages", %{utxos: utxos} do
    assert {:error, :amount_negative_value} == Transaction.create_from_utxos(utxos, %{address: "Joe", amount: -4})

    assert {:error, :amount_negative_value} == Transaction.create_from_utxos(utxos, %{address: "Joe", amount: 30_000})

    assert {:error, :too_many_utxo} ==
             Transaction.create_from_utxos(%{utxos | utxos: utxos.utxos ++ utxos.utxos}, %{address: "Joe", amount: 3})

    assert {:error, :invalid_fee} == Transaction.create_from_utxos(utxos, %{address: "Joe", amount: 4}, -1)

    first_utxo = utxos[:utxos] |> hd

    utxos_with_more_currencies =
      update_in(
        utxos[:utxos],
        &List.replace_at(&1, 0, %{first_utxo | currency: <<1::size(160)>>})
      )

    assert {:error, :currency_mixing_not_possible} ==
             Transaction.create_from_utxos(utxos_with_more_currencies, %{address: "Joe", amount: 4})
  end

  @tag fixtures: [:alice, :state_alice_deposit, :bob]
  test "using created transaction in child chain", %{alice: alice, bob: bob, state_alice_deposit: state} do
    state =
      state
      |> TestHelper.do_deposit(alice, %{amount: 10, currency: eth(), blknum: 2})

    utxos = %{
      address: alice.addr,
      utxos: [
        %{amount: 10, currency: eth(), blknum: 1, oindex: 0, txindex: 0},
        %{amount: 10, currency: eth(), blknum: 2, oindex: 0, txindex: 0}
      ]
    }

    {:ok, raw} = Transaction.create_from_utxos(utxos, %{address: bob.addr, amount: 12})

    raw |> Transaction.sign(alice.priv, alice.priv) |> assert_tx_usable(state)
  end

  @tag fixtures: [:alice, :state_alice_deposit, :bob]
  test "using created transaction with one input in child chain", %{alice: alice, bob: bob, state_alice_deposit: state} do
    utxos = %{
      address: alice.addr,
      utxos: [
        %{amount: 10, currency: eth(), blknum: 1, oindex: 0, txindex: 0}
      ]
    }

    {:ok, raw} = Transaction.create_from_utxos(utxos, %{address: bob.addr, amount: 4})

    raw |> Transaction.sign(alice.priv, <<>>) |> assert_tx_usable(state)
  end

  defp assert_tx_usable(signed, state_core) do
    {:ok, transaction} = signed |> Transaction.Signed.encode() |> API.Core.recover_tx()

    assert {:ok, {_, _, _}, _state} = Core.exec(transaction, %{eth() => 0}, state_core)
  end

  @tag fixtures: [:alice, :state_empty, :bob]
  test "Transactions created by :new and :create_from_utxos should be equal", %{alice: alice, bob: bob} do
    utxos = %{
      address: alice.addr,
      utxos: [
        %{amount: 10, currency: eth(), blknum: 1, oindex: 0, txindex: 0},
        %{amount: 11, currency: eth(), blknum: 2, oindex: 0, txindex: 0}
      ]
    }

    {:ok, tx1} = Transaction.create_from_utxos(utxos, %{address: bob.addr, amount: 16})

    tx2 = Transaction.new([{1, 0, 0}, {2, 0, 0}], eth(), [{bob.addr, 16}, {alice.addr, 5}])

    assert tx1 == tx2
  end

  @tag fixtures: [:alice, :bob]
  test "different signers, one output", %{alice: alice, bob: bob} do
    tx =
      [{3000, 0, 0}, {3000, 0, 1}]
      |> Transaction.new(eth(), [{alice.addr, 10}])
      |> Transaction.sign(bob.priv, alice.priv)
      |> Transaction.Signed.encode()

    {:ok, recovered} = tx |> OMG.API.Core.recover_tx()
    assert recovered.spender1 == bob.addr
    assert recovered.spender2 == alice.addr
  end
end
