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

  deffixture transaction do
    %Transaction{
      inputs: [%{blknum: 1, txindex: 1, oindex: 0}, %{blknum: 1, txindex: 2, oindex: 1}],
      outputs: [
        %{owner: "alicealicealicealice", currency: eth(), amount: 1},
        %{owner: "carolcarolcarolcarol", currency: eth(), amount: 2}
      ]
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
    {:ok, hash_value} = Base.decode16("e0e6fbd41f4909b4e621565fcdf6a0b54921711ff15a23d6cb07f1f87e345a33", case: :lower)
    assert Transaction.hash(transaction) == hash_value
  end

  @tag fixtures: [:utxos]
  test "create transaction with different number inputs and oputputs", %{utxos: utxos} do
    # 1 - input, 1 - output
    {:ok, transaction} =
      Transaction.create_from_utxos([hd(utxos)], [%{owner: "Joe Black", currency: eth(), amount: 99}])

    assert transaction == %Transaction{
             inputs: [%{blknum: 20, txindex: 42, oindex: 1} | List.duplicate(%{blknum: 0, oindex: 0, txindex: 0}, 3)],
             outputs: [
               %{owner: "Joe Black", currency: eth(), amount: 99}
               | List.duplicate(%{owner: Crypto.zero_address(), currency: eth(), amount: 0}, 3)
             ]
           }

    # 1 - input, 2 - outputs
    {:ok, transaction} =
      Transaction.create_from_utxos(
        utxos |> tl(),
        [%{owner: "Joe Black", currency: eth(), amount: 22}, %{owner: "McDuck", currency: eth(), amount: 21}]
      )

    assert transaction == %Transaction{
             inputs: [%{blknum: 2, txindex: 21, oindex: 0} | List.duplicate(%{blknum: 0, txindex: 0, oindex: 0}, 3)],
             outputs: [
               %{owner: "Joe Black", currency: eth(), amount: 22},
               %{owner: "McDuck", currency: eth(), amount: 21}
               | List.duplicate(%{owner: Crypto.zero_address(), currency: eth(), amount: 0}, 2)
             ]
           }

    # 2 - inputs, 2 - outputs
    {:ok, transaction} =
      Transaction.create_from_utxos(
        utxos,
        [%{owner: "Joe Black", currency: eth(), amount: 53}, %{owner: "McDuck", currency: eth(), amount: 90}]
      )

    assert transaction == %Transaction{
             inputs: [
               %{blknum: 20, txindex: 42, oindex: 1},
               %{blknum: 2, txindex: 21, oindex: 0} | List.duplicate(%{blknum: 0, txindex: 0, oindex: 0}, 2)
             ],
             outputs: [
               %{owner: "Joe Black", currency: eth(), amount: 53},
               %{owner: "McDuck", currency: eth(), amount: 90}
               | List.duplicate(%{owner: Crypto.zero_address(), currency: eth(), amount: 0}, 2)
             ]
           }

    # 2 - inputs, 0 - outputs
    {:ok, transaction} = Transaction.create_from_utxos(utxos, [])

    assert transaction == %Transaction{
             inputs: [
               %{blknum: 20, txindex: 42, oindex: 1},
               %{blknum: 2, txindex: 21, oindex: 0} | List.duplicate(%{blknum: 0, txindex: 0, oindex: 0}, 2)
             ],
             outputs: List.duplicate(%{owner: Crypto.zero_address(), currency: eth(), amount: 0}, 4)
           }
  end

  @tag fixtures: [:utxos]
  test "checking input validation error messages", %{utxos: utxos} do
    assert {:error, :inputs_should_be_list} == Transaction.create_from_utxos(%{}, [])

    assert {:error, :outputs_should_be_list} == Transaction.create_from_utxos(utxos, %{})

    assert {:error, :at_least_one_input_required} == Transaction.create_from_utxos([], [])

    assert {:error, :too_many_inputs} == Transaction.create_from_utxos(utxos ++ utxos ++ utxos, [])

    assert {:error, :too_many_outputs} == Transaction.create_from_utxos(utxos, [%{}, %{}, %{}, %{}, %{}])

    assert {:error, :amount_noninteger_or_negative} ==
             Transaction.create_from_utxos(utxos, [%{owner: "Joe", currency: eth(), amount: -4}])

    utxo_with_neg_amount = %{(utxos |> hd()) | amount: -10}

    assert {:error, :amount_noninteger_or_negative} ==
             Transaction.create_from_utxos([utxo_with_neg_amount], [%{owner: "Joe", currency: eth(), amount: 4}])

    assert {:error, :amount_noninteger_or_negative} ==
             Transaction.create_from_utxos(utxos, [%{owner: "Joe", currency: eth(), amount: "NaN"}])

    assert {:error, :not_enough_funds_to_cover_spend} ==
             Transaction.create_from_utxos(utxos, [%{owner: "Joe", currency: eth(), amount: 144}])

    [first_utxo, second_utxo] = utxos

    utxos_with_more_currencies = [%{first_utxo | currency: <<1::size(160)>>}] ++ [second_utxo]

    assert {:error, :currency_mixing_not_possible} ==
             Transaction.create_from_utxos(
               utxos_with_more_currencies,
               [%{owner: "Joe", currency: eth(), amount: 4}]
             )
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

    {:ok, raw} = Transaction.create_from_utxos(utxos, [%{owner: bob.addr, currency: eth(), amount: 12}])

    raw |> Transaction.sign([alice.priv, alice.priv]) |> assert_tx_usable(state)
  end

  @tag fixtures: [:alice, :state_alice_deposit, :bob]
  test "using created transaction with one input in child chain", %{alice: alice, bob: bob, state_alice_deposit: state} do
    utxos = [
      %{amount: 10, currency: eth(), blknum: 1, oindex: 0, txindex: 0}
    ]

    {:ok, raw} = Transaction.create_from_utxos(utxos, [%{owner: bob.addr, currency: eth(), amount: 4}])

    raw |> Transaction.sign([alice.priv, <<>>]) |> assert_tx_usable(state)
  end

  defp assert_tx_usable(signed, state_core) do
    {:ok, transaction} = signed |> Transaction.Signed.encode() |> API.Core.recover_tx()

    assert {:ok, {_, _, _}, _state} = Core.exec(transaction, %{eth() => 0}, state_core)
  end

  @tag fixtures: [:alice, :state_empty, :bob]
  test "transactions created by :new and :create_from_utxos should be equal", %{alice: alice, bob: bob} do
    utxos = [
      %{amount: 10, currency: eth(), blknum: 1, oindex: 0, txindex: 0},
      %{amount: 11, currency: eth(), blknum: 2, oindex: 0, txindex: 0}
    ]

    {:ok, tx1} =
      Transaction.create_from_utxos(
        utxos,
        [%{owner: bob.addr, currency: eth(), amount: 16}, %{owner: alice.addr, currency: eth(), amount: 5}]
      )

    tx2 = Transaction.new([{1, 0, 0}, {2, 0, 0}], [{bob.addr, eth(), 16}, {alice.addr, eth(), 5}])

    assert tx1 == tx2
  end

  @tag fixtures: [:alice, :bob]
  test "different signers, one output", %{alice: alice, bob: bob} do
    tx =
      [{3000, 0, 0}, {3000, 0, 1}]
      |> Transaction.new([{alice.addr, eth(), 10}])
      |> Transaction.sign([bob.priv, alice.priv])
      |> Transaction.Signed.encode()

    {:ok, recovered} = tx |> OMG.API.Core.recover_tx()
    assert recovered.spenders == [bob.addr, alice.addr]
  end

  @tag fixtures: [:alice, :bob, :carol]
  test "checks if spenders are authorized", %{alice: alice, bob: bob, carol: carol} do
    authorized_tx =
      TestHelper.create_recovered([{1, 1, 0, alice}, {1, 3, 0, bob}], eth(), [
        {bob, 6},
        {alice, 4}
      ])

    :ok = Transaction.Recovered.all_spenders_authorized?(authorized_tx, [bob.addr, alice.addr])
    {:error, :unauthorized_spent} = Transaction.Recovered.all_spenders_authorized?(authorized_tx, [carol.addr])

    {:error, :unauthorized_spent} =
      Transaction.Recovered.all_spenders_authorized?(authorized_tx, [alice.addr, carol.addr])
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
