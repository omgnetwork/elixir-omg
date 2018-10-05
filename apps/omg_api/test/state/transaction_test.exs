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
    [
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
  test "create transaction with different number inputs and oputputs", %{utxos: utxos} do
    # 1 - input, 1 - output
    {:ok, transaction} = Transaction.create_from_utxos([utxos |> hd()], [%{owner: "Joe Black", amount: 99}], 0)

    assert transaction == %Transaction{
             blknum1: 20,
             txindex1: 42,
             oindex1: 1,
             blknum2: 0,
             txindex2: 0,
             oindex2: 0,
             cur12: eth(),
             newowner1: "Joe Black",
             amount1: 99,
             newowner2: Crypto.zero_address(),
             amount2: 0
           }

    # 1 - input, 2 - outputs
    {:ok, transaction} =
      Transaction.create_from_utxos(
        utxos |> tl(),
        [%{owner: "Joe Black", amount: 22}, %{owner: "McDuck", amount: 21}],
        0
      )

    assert transaction == %Transaction{
             blknum1: 2,
             txindex1: 21,
             oindex1: 0,
             blknum2: 0,
             txindex2: 0,
             oindex2: 0,
             cur12: eth(),
             newowner1: "Joe Black",
             amount1: 22,
             newowner2: "McDuck",
             amount2: 21
           }

    # 2 - inputs, 2 - outputs
    {:ok, transaction} =
      Transaction.create_from_utxos(utxos, [%{owner: "Joe Black", amount: 53}, %{owner: "McDuck", amount: 90}], 0)

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

    # 2 - inputs, 0 - outputs
    {:ok, transaction} = Transaction.create_from_utxos(utxos, [], 0)

    assert transaction == %Transaction{
             blknum1: 20,
             txindex1: 42,
             oindex1: 1,
             blknum2: 2,
             txindex2: 21,
             oindex2: 0,
             cur12: eth(),
             newowner1: Crypto.zero_address(),
             amount1: 0,
             newowner2: Crypto.zero_address(),
             amount2: 0
           }
  end

  @tag fixtures: [:utxos]
  test "checking input validation error messages", %{utxos: utxos} do
    assert {:error, :inputs_should_be_list} == Transaction.create_from_utxos(%{}, [], 0)

    assert {:error, :outputs_should_be_list} == Transaction.create_from_utxos(utxos, %{}, 0)

    assert {:error, :at_least_one_input_required} == Transaction.create_from_utxos([], [], 0)

    assert {:error, :too_many_inputs} == Transaction.create_from_utxos(utxos ++ utxos, [], 0)

    assert {:error, :too_many_outputs} == Transaction.create_from_utxos(utxos, [%{}, %{}, %{}], 0)

    assert {:error, :amount_noninteger_or_negative} ==
             Transaction.create_from_utxos(utxos, [%{owner: "Joe", amount: -4}], 0)

    utxo_with_neg_amount = %{(utxos |> hd()) | amount: -10}

    assert {:error, :amount_noninteger_or_negative} ==
             Transaction.create_from_utxos([utxo_with_neg_amount], [%{owner: "Joe", amount: 4}], 0)

    assert {:error, :amount_noninteger_or_negative} ==
             Transaction.create_from_utxos(utxos, [%{owner: "Joe", amount: "NaN"}], 0)

    assert {:error, :not_enough_funds_to_cover_spend} ==
             Transaction.create_from_utxos(utxos, [%{owner: "Joe", amount: 144}], 0)

    assert {:error, :not_enough_funds_to_cover_fee} ==
             Transaction.create_from_utxos(utxos, [%{owner: "Joe", amount: 140}], 5)

    assert {:error, :invalid_fee} == Transaction.create_from_utxos(utxos, [%{owner: "Joe", amount: 4}], -1)

    [first_utxo, second_utxo] = utxos

    utxos_with_more_currencies = [%{first_utxo | currency: <<1::size(160)>>}] ++ [second_utxo]

    assert {:error, :currency_mixing_not_possible} ==
             Transaction.create_from_utxos(utxos_with_more_currencies, [%{owner: "Joe", amount: 4}], 0)
  end

  @tag fixtures: [:alice, :state_alice_deposit, :bob]
  test "using created transaction in child chain", %{alice: alice, bob: bob, state_alice_deposit: state} do
    state =
      state
      |> TestHelper.do_deposit(alice, %{amount: 10, currency: eth(), blknum: 2})

    utxos = [
      %{amount: 10, currency: eth(), blknum: 1, oindex: 0, txindex: 0},
      %{amount: 10, currency: eth(), blknum: 2, oindex: 0, txindex: 0}
    ]

    {:ok, raw} = Transaction.create_from_utxos(utxos, [%{owner: bob.addr, amount: 12}], 0)

    raw |> Transaction.sign(alice.priv, alice.priv) |> assert_tx_usable(state)
  end

  @tag fixtures: [:alice, :state_alice_deposit, :bob]
  test "using created transaction with one input in child chain", %{alice: alice, bob: bob, state_alice_deposit: state} do
    utxos = [
      %{amount: 10, currency: eth(), blknum: 1, oindex: 0, txindex: 0}
    ]

    {:ok, raw} = Transaction.create_from_utxos(utxos, [%{owner: bob.addr, amount: 4}], 0)

    raw |> Transaction.sign(alice.priv, <<>>) |> assert_tx_usable(state)
  end

  defp assert_tx_usable(signed, state_core) do
    {:ok, transaction} = signed |> Transaction.Signed.encode() |> API.Core.recover_tx()

    assert {:ok, {_, _, _}, _state} = Core.exec(transaction, %{eth() => 0}, state_core)
  end

  @tag fixtures: [:alice, :state_empty, :bob]
  test "Transactions created by :new and :create_from_utxos should be equal", %{alice: alice, bob: bob} do
    utxos = [
      %{amount: 10, currency: eth(), blknum: 1, oindex: 0, txindex: 0},
      %{amount: 11, currency: eth(), blknum: 2, oindex: 0, txindex: 0}
    ]

    {:ok, tx1} =
      Transaction.create_from_utxos(utxos, [%{owner: bob.addr, amount: 16}, %{owner: alice.addr, amount: 5}], 0)

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
