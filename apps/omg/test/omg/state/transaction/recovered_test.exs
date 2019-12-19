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

defmodule OMG.State.Transaction.RecoveredTest do
  @moduledoc """
  This test the public-most APIs regarging the transaction, being mainly centered around:
    - recovery and stateless validation done in `Transaction.Recovered`
    - usability of recovered transactions in `OMG.State`
    - detecting and reporting invalidly encoded, malformed, illegal transactions
  """
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.DevCrypto
  alias OMG.State
  alias OMG.State.Transaction
  alias OMG.TestHelper
  alias OMG.Utxo
  alias OMG.WireFormatTypes

  require Utxo

  @payment_tx_type WireFormatTypes.tx_type_for(:tx_payment_v1)
  @payment_output_type WireFormatTypes.output_type_for(:output_payment_v1)

  @zero_address OMG.Eth.zero_address()
  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @empty_signature <<0::size(520)>>

  describe "APIs used by the `OMG.State.exec/1`" do
    @tag fixtures: [:alice, :state_alice_deposit, :bob]
    test "using created transaction in child chain", %{alice: alice, bob: bob, state_alice_deposit: state} do
      state = TestHelper.do_deposit(state, alice, %{amount: 10, currency: @eth, blknum: 2})

      payment = Transaction.Payment.new([{1, 0, 0}, {2, 0, 0}], [{bob.addr, @eth, 12}])

      payment
      |> DevCrypto.sign([alice.priv, alice.priv])
      |> assert_tx_usable(state)
    end

    @tag fixtures: [:alice, :state_alice_deposit, :bob]
    test "using created transaction with one input in child chain", %{
      alice: alice,
      bob: bob,
      state_alice_deposit: state
    } do
      payment = Transaction.Payment.new([{1, 0, 0}], [{bob.addr, @eth, 4}])

      payment
      |> DevCrypto.sign([alice.priv])
      |> assert_tx_usable(state)
    end

    @tag fixtures: [:alice, :bob]
    test "recovering spenders: different signers, one output", %{alice: alice, bob: bob} do
      {:ok, recovered} =
        [{3000, 0, 0}, {3000, 0, 1}]
        |> Transaction.Payment.new([{alice.addr, @eth, 10}])
        |> DevCrypto.sign([bob.priv, alice.priv])
        |> Transaction.Signed.encode()
        |> Transaction.Recovered.recover_from()

      assert recovered.witnesses == %{0 => bob.addr, 1 => alice.addr}
    end

    @tag fixtures: [:alice, :bob]
    test "signed transaction is valid in various empty input/output combinations", %{
      alice: alice,
      bob: bob
    } do
      transaction_list = [
        {[], [{alice, @eth, 7}]},
        {[{1, 2, 3, alice}], [{alice, @eth, 7}]},
        {[{1, 2, 3, alice}], [{alice, @eth, 7}, {bob, @eth, 3}]},
        {[{1, 2, 3, alice}, {2, 3, 4, bob}], [{alice, @eth, 7}, {bob, @eth, 3}]},
        {[{1, 2, 3, alice}, {2, 3, 4, bob}, {2, 3, 5, bob}], [{alice, @eth, 7}, {bob, @eth, 3}]},
        {[{1, 2, 3, alice}, {2, 3, 4, bob}, {2, 3, 5, bob}], [{alice, @eth, 7}, {bob, @eth, 3}, {bob, @eth, 3}]},
        {[{1, 2, 3, alice}, {2, 3, 1, alice}, {2, 3, 2, bob}, {3, 3, 4, bob}],
         [{alice, @eth, 7}, {alice, @eth, 3}, {bob, @eth, 7}, {bob, @eth, 3}]}
      ]

      Enum.map(transaction_list, &parametrized_tester/1)
    end
  end

  describe "encoding/decoding is done properly" do
    @tag fixtures: [:alice]
    test "decoding malformed signed payment transaction", %{alice: alice} do
      payment = Transaction.Payment.new([{1, 0, 0}, {2, 0, 0}], [{alice.addr, @eth, 12}])
      tx = DevCrypto.sign(payment, [alice.priv, alice.priv])
      %Transaction.Signed{sigs: sigs} = tx

      [_payment_marker, inputs, outputs, _txdata, _metadata] = tx |> Transaction.raw_txbytes() |> ExRLP.decode()

      # sanity
      assert {:ok, _} =
               Transaction.Recovered.recover_from(
                 ExRLP.encode([sigs, @payment_tx_type, inputs, outputs, 0, <<0::256>>])
               )

      assert {:error, :malformed_transaction} = Transaction.Recovered.recover_from(<<192>>)
      assert {:error, :malformed_transaction} = Transaction.Recovered.recover_from(<<0x80>>)
      assert {:error, :malformed_transaction} = Transaction.Recovered.recover_from(<<>>)
      assert {:error, :malformed_transaction} = Transaction.Recovered.recover_from(ExRLP.encode(23))
      assert {:error, :malformed_transaction} = Transaction.Recovered.recover_from(ExRLP.encode([sigs, 1]))

      # looks like a payment transaction but type points to a `FeeTokenClaim` transaction, hence malformed not
      # unrecognized
      assert {:error, :malformed_transaction} =
               Transaction.Recovered.recover_from(ExRLP.encode([sigs, 3, inputs, outputs, 0, <<0::256>>]))

      assert {:error, :malformed_transaction} =
               Transaction.Recovered.recover_from(ExRLP.encode([sigs, 1, outputs, 0, <<0::256>>]))

      assert {:error, :unrecognized_transaction_type} =
               Transaction.Recovered.recover_from(ExRLP.encode([sigs, ["bad"], inputs, outputs, 0, <<0::256>>]))

      assert {:error, :unrecognized_transaction_type} = Transaction.Recovered.recover_from(ExRLP.encode([sigs, []]))

      assert {:error, :unrecognized_transaction_type} =
               Transaction.Recovered.recover_from(ExRLP.encode([sigs, 234_567, inputs, outputs, 0, <<0::256>>]))

      assert {:error, :malformed_witnesses} ==
               Transaction.Recovered.recover_from(
                 ExRLP.encode([[<<1>>, <<1>>], @payment_tx_type, inputs, outputs, 0, <<0::256>>])
               )

      assert {:error, :malformed_witnesses} ==
               Transaction.Recovered.recover_from(
                 ExRLP.encode([<<1>>, @payment_tx_type, inputs, outputs, 0, <<0::256>>])
               )

      assert {:error, :malformed_inputs} =
               Transaction.Recovered.recover_from(ExRLP.encode([sigs, @payment_tx_type, 42, outputs, 0, <<0::256>>]))

      assert {:error, :malformed_inputs} =
               Transaction.Recovered.recover_from(
                 ExRLP.encode([sigs, @payment_tx_type, [[1, 2]], outputs, 0, <<0::256>>])
               )

      assert {:error, :malformed_inputs} =
               Transaction.Recovered.recover_from(
                 ExRLP.encode([sigs, @payment_tx_type, [[1, 2, 'a']], outputs, 0, <<0::256>>])
               )

      assert {:error, :malformed_outputs} =
               Transaction.Recovered.recover_from(ExRLP.encode([sigs, @payment_tx_type, inputs, 42, 0, <<0::256>>]))

      assert {:error, :malformed_outputs} =
               Transaction.Recovered.recover_from(
                 ExRLP.encode([
                   sigs,
                   @payment_tx_type,
                   inputs,
                   [[@payment_output_type, alice.addr, alice.addr, 1]],
                   0,
                   <<0::256>>
                 ])
               )

      assert {:error, :malformed_outputs} =
               Transaction.Recovered.recover_from(
                 ExRLP.encode([
                   sigs,
                   @payment_tx_type,
                   inputs,
                   [[@payment_output_type, [alice.addr, alice.addr]]],
                   0,
                   <<0::256>>
                 ])
               )

      assert {:error, :malformed_outputs} =
               Transaction.Recovered.recover_from(
                 ExRLP.encode([
                   sigs,
                   @payment_tx_type,
                   inputs,
                   [[@payment_output_type, [alice.addr, alice.addr, 'a']]],
                   0,
                   <<0::256>>
                 ])
               )

      assert {:error, :unrecognized_output_type} =
               Transaction.Recovered.recover_from(
                 ExRLP.encode([sigs, @payment_tx_type, inputs, [[<<232>>, [alice.addr, alice.addr, 1]]], 0, <<0::256>>])
               )

      assert {:error, :malformed_tx_data} =
               Transaction.Recovered.recover_from(
                 ExRLP.encode([sigs, @payment_tx_type, inputs, outputs, 1, <<0::256>>])
               )

      assert {:error, :malformed_uint256} =
               Transaction.Recovered.recover_from(
                 ExRLP.encode([sigs, @payment_tx_type, inputs, outputs, [<<6>>], <<0::256>>])
               )

      assert {:error, :leading_zeros_in_encoded_uint} =
               Transaction.Recovered.recover_from(
                 ExRLP.encode([sigs, @payment_tx_type, inputs, outputs, <<0::256>>, <<0::256>>])
               )

      assert {:error, :leading_zeros_in_encoded_uint} =
               Transaction.Recovered.recover_from(
                 ExRLP.encode([sigs, @payment_tx_type, inputs, outputs, <<1::256>>, <<0::256>>])
               )

      assert {:error, :malformed_metadata} =
               Transaction.Recovered.recover_from(ExRLP.encode([sigs, @payment_tx_type, inputs, outputs, 0, ""]))

      assert {:error, :malformed_metadata} =
               Transaction.Recovered.recover_from(ExRLP.encode([sigs, @payment_tx_type, inputs, outputs, 0, []]))

      assert {:error, :malformed_metadata} =
               Transaction.Recovered.recover_from(
                 ExRLP.encode([sigs, @payment_tx_type, inputs, outputs, 0, <<1::224>>])
               )

      assert {:error, :malformed_metadata} =
               Transaction.Recovered.recover_from(
                 ExRLP.encode([sigs, @payment_tx_type, inputs, outputs, 0, <<2::288>>])
               )
    end

    @tag fixtures: [:alice, :bob]
    test "rlp encoding of a transaction is corrupt", %{alice: alice, bob: bob} do
      encoded_signed_tx = TestHelper.create_encoded([{1, 2, 3, alice}, {2, 3, 4, bob}], @eth, [{alice, 7}])

      malformed2 = "A" <> encoded_signed_tx
      assert {:error, :malformed_transaction_rlp} = Transaction.Recovered.recover_from(malformed2)

      <<_, malformed3::binary>> = encoded_signed_tx
      assert {:error, :malformed_transaction_rlp} = Transaction.Recovered.recover_from(malformed3)

      cropped_size = byte_size(encoded_signed_tx) - 1
      <<malformed4::binary-size(cropped_size), _::binary-size(1)>> = encoded_signed_tx
      assert {:error, :malformed_transaction_rlp} = Transaction.Recovered.recover_from(malformed4)
    end

    @tag fixtures: [:alice, :bob]
    test "address in encoded transaction malformed", %{alice: alice, bob: bob} do
      malformed_alice = %{addr: "0x00000000000000000"}
      malformed_eth = "0x00000000000000000"
      malformed_signed1 = TestHelper.create_signed([{1, 2, 3, alice}, {2, 3, 4, bob}], @eth, [{malformed_alice, 7}])
      malformed_signed2 = TestHelper.create_signed([{1, 2, 3, alice}, {2, 3, 4, bob}], malformed_eth, [{alice, 7}])

      malformed_signed3 =
        TestHelper.create_signed([{1, 2, 3, alice}, {2, 3, 4, bob}], @eth, [{alice, 7}, {malformed_alice, 3}])

      malformed1 = Transaction.Signed.encode(malformed_signed1)
      malformed2 = Transaction.Signed.encode(malformed_signed2)
      malformed3 = Transaction.Signed.encode(malformed_signed3)

      assert {:error, :malformed_address} = Transaction.Recovered.recover_from(malformed1)
      assert {:error, :malformed_address} = Transaction.Recovered.recover_from(malformed2)
      assert {:error, :malformed_address} = Transaction.Recovered.recover_from(malformed3)
    end

    @tag fixtures: [:alice]
    test "transactions with corrupt signatures don't do harm - one signature", %{alice: alice} do
      full_signed_tx = TestHelper.create_signed([{1, 2, 3, alice}], @eth, [{alice, 7}])

      assert {:error, :signature_corrupt} ==
               %Transaction.Signed{full_signed_tx | sigs: [<<1::size(520)>>]}
               |> Transaction.Signed.encode()
               |> Transaction.Recovered.recover_from()
    end

    @tag fixtures: [:alice]
    test "transactions with corrupt signatures don't do harm - one of many signatures", %{alice: alice} do
      full_signed_tx = TestHelper.create_signed([{1, 2, 3, alice}, {1, 2, 4, alice}], @eth, [{alice, 7}])
      %Transaction.Signed{sigs: [sig1, sig2 | _]} = full_signed_tx

      assert {:error, :signature_corrupt} ==
               %Transaction.Signed{full_signed_tx | sigs: [sig1, <<1::size(520)>>]}
               |> Transaction.Signed.encode()
               |> Transaction.Recovered.recover_from()

      assert {:error, :signature_corrupt} ==
               %Transaction.Signed{full_signed_tx | sigs: [<<1::size(520)>>, sig2]}
               |> Transaction.Signed.encode()
               |> Transaction.Recovered.recover_from()
    end
  end

  describe "stateless validity critical to the ledger is checked" do
    @tag fixtures: [:alice]
    test "transaction must have distinct inputs", %{alice: alice} do
      duplicate_inputs = TestHelper.create_encoded([{1, 2, 3, alice}, {1, 2, 3, alice}], @eth, [{alice, 7}])

      assert {:error, :duplicate_inputs} = Transaction.Recovered.recover_from(duplicate_inputs)
    end
  end

  describe "formal protocol rules are enforced" do
    @tag fixtures: [:alice]
    test "Decoding transaction with gaps in inputs is ok now, but 0 utxo pos is illegal", %{alice: alice} do
      # explicitly testing the behavior that we have instead of the obsolete gap checking

      encoded_transaction = TestHelper.create_encoded([{0, 0, 0, alice}, {1000, 0, 0, alice}], @eth, [{alice, 100}])
      assert {:error, :malformed_inputs} = Transaction.Recovered.recover_from(encoded_transaction)
    end

    @tag fixtures: [:alice]
    test "Decoding deposit transaction without inputs is successful", %{alice: alice} do
      encoded_transaction = TestHelper.create_encoded([], @eth, [{alice, 100}])
      assert {:ok, _} = Transaction.Recovered.recover_from(encoded_transaction)
    end

    @tag fixtures: [:alice]
    test "Decoding transaction with zero input fails", %{alice: alice} do
      encoded_transaction = TestHelper.create_encoded([{0, 0, 0, alice}], [{alice, @zero_address, 10}])
      assert {:error, :malformed_inputs} = Transaction.Recovered.recover_from(encoded_transaction)
    end

    @tag fixtures: [:alice]
    test "Decoding transaction with zero blknum works as long as input non-zero", %{alice: alice} do
      encoded_transaction = TestHelper.create_encoded([{0, 0, 1, alice}], [{alice, @zero_address, 10}])
      assert {:ok, _} = Transaction.Recovered.recover_from(encoded_transaction)
    end

    test "Decoding transaction with list as transaction type fails" do
      tx_type_index_in_rlp = 1

      assert {:error, :unrecognized_transaction_type} =
               good_tx_rlp_items()
               |> List.replace_at(tx_type_index_in_rlp, [<<1>>])
               |> ExRLP.encode()
               |> Transaction.Recovered.recover_from()
    end

    test "Decoding transaction with too many inputs fails" do
      inputs_index_in_rlp = 2
      [input] = Enum.at(good_tx_rlp_items(), inputs_index_in_rlp)

      assert {:error, :too_many_inputs} =
               good_tx_rlp_items()
               |> List.replace_at(inputs_index_in_rlp, List.duplicate(input, 5))
               |> ExRLP.encode()
               |> Transaction.Recovered.recover_from()
    end

    test "Decoding transaction with shorter input fails" do
      inputs_index_in_rlp = 2
      [input] = Enum.at(good_tx_rlp_items(), inputs_index_in_rlp)

      assert {:error, :malformed_inputs} =
               good_tx_rlp_items()
               |> List.replace_at(inputs_index_in_rlp, [binary_part(input, 1, 31)])
               |> ExRLP.encode()
               |> Transaction.Recovered.recover_from()
    end

    test "Decoding transaction with shorter/longer/malformed address fails" do
      outputs_index_in_rlp = 3
      [[type, [owner, currency, amount]]] = Enum.at(good_tx_rlp_items(), outputs_index_in_rlp)

      checker = fn bad_output ->
        assert {:error, :malformed_address} =
                 good_tx_rlp_items()
                 |> List.replace_at(outputs_index_in_rlp, [bad_output])
                 |> ExRLP.encode()
                 |> Transaction.Recovered.recover_from()
      end

      transaction_list = [
        [type, [binary_part(owner, 1, 19), currency, amount]],
        [type, [binary_part(owner, 0, 19), currency, amount]],
        [type, [owner, binary_part(currency, 1, 19), amount]],
        [type, [owner, binary_part(currency, 0, 19), amount]],
        [type, [owner, <<1>>, amount]],
        [type, [<<1>>, currency, amount]],
        [type, [owner, "", amount]],
        [type, ["", currency, amount]],
        [type, [<<1>>, currency, amount]],
        # address-like (21 bytes encoded) items being lists
        [type, [owner, [<<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>, <<3>>, <<1>>, <<1>>], amount]],
        [type, [[<<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>, <<3>>, <<1>>, <<1>>], currency, amount]]
      ]

      Enum.map(transaction_list, checker)
    end

    @tag fixtures: [:alice]
    test "Decoding transaction with zero amount in outputs fails ", %{alice: alice} do
      encoded_transaction = TestHelper.create_encoded([{1000, 0, 0, alice}], @eth, [{alice, 0}, {alice, 100}])
      assert {:error, :amount_cant_be_zero} = Transaction.Recovered.recover_from(encoded_transaction)
    end

    @tag fixtures: [:alice]
    test "Decoding transaction with zero output guard in outputs fails ", %{alice: alice} do
      no_account = %{addr: @zero_address}

      assert {:error, :output_guard_cant_be_zero} =
               Transaction.Recovered.recover_from(
                 TestHelper.create_encoded([{1000, 0, 0, alice}], @eth, [{no_account, 10}, {alice, 100}])
               )
    end

    @tag fixtures: [:alice]
    test "Decoding transaction with zero output fails", %{alice: alice} do
      no_account = %{addr: @zero_address}

      assert {:error, :output_guard_cant_be_zero} =
               Transaction.Recovered.recover_from(
                 TestHelper.create_encoded([{1000, 0, 0, alice}], [{no_account, @zero_address, 0}])
               )
    end

    test "Decoding transaction with zero output type fails" do
      outputs_index_in_rlp = 3
      [[_type, output_fields]] = Enum.at(good_tx_rlp_items(), outputs_index_in_rlp)
      bad_output = [0, output_fields]

      assert {:error, :unrecognized_output_type} =
               good_tx_rlp_items()
               |> List.replace_at(outputs_index_in_rlp, [bad_output])
               |> ExRLP.encode()
               |> Transaction.Recovered.recover_from()
    end

    test "Decoding transaction with list as output type fails" do
      outputs_index_in_rlp = 3
      [[_type, output_fields]] = Enum.at(good_tx_rlp_items(), outputs_index_in_rlp)
      bad_output = [[<<1>>], output_fields]

      assert {:error, :unrecognized_output_type} =
               good_tx_rlp_items()
               |> List.replace_at(outputs_index_in_rlp, [bad_output])
               |> ExRLP.encode()
               |> Transaction.Recovered.recover_from()
    end

    test "Decoding transaction with malformed output fails" do
      outputs_index_in_rlp = 3
      [output] = Enum.at(good_tx_rlp_items(), outputs_index_in_rlp)

      assert {:error, :malformed_outputs} =
               good_tx_rlp_items()
               |> List.replace_at(outputs_index_in_rlp, output)
               |> ExRLP.encode()
               |> Transaction.Recovered.recover_from()
    end

    test "Decoding transaction with leading-zeros in output amount fails" do
      outputs_index_in_rlp = 3
      [[type, [owner, currency, _amount]]] = Enum.at(good_tx_rlp_items(), outputs_index_in_rlp)

      checker = fn bad_amount ->
        assert {:error, :leading_zeros_in_encoded_uint} =
                 good_tx_rlp_items()
                 |> List.replace_at(outputs_index_in_rlp, [[type, [owner, currency, bad_amount]]])
                 |> ExRLP.encode()
                 |> Transaction.Recovered.recover_from()
      end

      [<<1::288>>, <<1::224>>, <<1::64>>, <<0, 1>>]
      |> Enum.map(checker)
    end

    test "Decoding transaction with not-a-uint256 in output amount fails" do
      outputs_index_in_rlp = 3
      [[type, [owner, currency, _amount]]] = Enum.at(good_tx_rlp_items(), outputs_index_in_rlp)

      assert {:error, :malformed_outputs} =
               good_tx_rlp_items()
               |> List.replace_at(outputs_index_in_rlp, [[type, [owner, currency, [<<6>>]]]])
               |> ExRLP.encode()
               |> Transaction.Recovered.recover_from()
    end

    test "Decoding transaction with >32 bytes in output amount fails" do
      outputs_index_in_rlp = 3
      [[type, [owner, currency, _amount]]] = Enum.at(good_tx_rlp_items(), outputs_index_in_rlp)
      bad_amount = :binary.copy(<<1>>, 33)

      assert {:error, :encoded_uint_too_big} =
               good_tx_rlp_items()
               |> List.replace_at(outputs_index_in_rlp, [[type, [owner, currency, bad_amount]]])
               |> ExRLP.encode()
               |> Transaction.Recovered.recover_from()
    end

    test "Decoding transaction a list in output amount fails" do
      outputs_index_in_rlp = 3
      [[type, [owner, currency, _amount]]] = Enum.at(good_tx_rlp_items(), outputs_index_in_rlp)
      bad_amount = [<<1>>]

      assert {:error, :malformed_outputs} =
               good_tx_rlp_items()
               |> List.replace_at(outputs_index_in_rlp, [[type, [owner, currency, bad_amount]]])
               |> ExRLP.encode()
               |> Transaction.Recovered.recover_from()
    end

    test "Decoding transaction with too many outputs fails" do
      outputs_index_in_rlp = 3
      [output] = Enum.at(good_tx_rlp_items(), outputs_index_in_rlp)

      assert {:error, :too_many_outputs} =
               good_tx_rlp_items()
               |> List.replace_at(outputs_index_in_rlp, List.duplicate(output, 5))
               |> ExRLP.encode()
               |> Transaction.Recovered.recover_from()
    end

    @tag fixtures: [:alice]
    test "Decoding transaction without outputs fails", %{alice: alice} do
      assert {:error, :empty_outputs} =
               TestHelper.create_encoded([{1000, 0, 0, alice}], @eth, [])
               |> Transaction.Recovered.recover_from()
    end

    @tag fixtures: [:alice, :bob]
    test "transaction is not allowed to have input and empty sigs", %{alice: alice} do
      tx = TestHelper.create_signed([{1, 2, 3, alice}, {2, 3, 4, alice}], @eth, [{alice, 7}])
      tx_no_sigs = %{tx | sigs: [@empty_signature, @empty_signature]}
      tx_hash = Transaction.Signed.encode(tx_no_sigs)
      assert {:error, :missing_signature} == Transaction.Recovered.recover_from(tx_hash)
    end

    @tag fixtures: [:alice]
    test "transactions with superfluous signatures don't do harm", %{alice: alice} do
      full_signed_tx = TestHelper.create_signed([{1, 2, 3, alice}], @eth, [{alice, 7}])
      %Transaction.Signed{sigs: [sig1 | _]} = full_signed_tx

      assert {:error, :superfluous_signature} ==
               %Transaction.Signed{full_signed_tx | sigs: [sig1, sig1]}
               |> Transaction.Signed.encode()
               |> Transaction.Recovered.recover_from()
    end
  end

  defp assert_tx_usable(signed, state_core) do
    {:ok, transaction} = signed |> Transaction.Signed.encode() |> Transaction.Recovered.recover_from()
    assert {:ok, {_, _, _}, _state} = State.Core.exec(state_core, transaction, :no_fees_required)
  end

  defp parametrized_tester({inputs, outputs}) do
    tx = TestHelper.create_signed(inputs, outputs)

    encoded_signed_tx = Transaction.Signed.encode(tx)

    witnesses =
      inputs
      |> Enum.filter(fn {_, _, _, %{addr: addr}} -> addr != nil end)
      |> Enum.map(fn {_, _, _, spender} -> spender.addr end)
      |> Enum.with_index()
      |> Enum.into(%{}, fn {witness, index} -> {index, witness} end)

    assert {:ok,
            %Transaction.Recovered{
              signed_tx: ^tx,
              witnesses: ^witnesses
            }} = Transaction.Recovered.recover_from(encoded_signed_tx)
  end

  # provides one with RLP items (ready for `ExRLP.encode/1`) representing a valid transaction
  defp good_tx_rlp_items() do
    alice = TestHelper.generate_entity()

    good_tx_rlp_items =
      TestHelper.create_encoded([{1000, 0, 0, alice}], [{alice, @eth, 10}])
      |> ExRLP.decode()

    # sanity check just in case
    assert {:ok, _} =
             good_tx_rlp_items
             |> ExRLP.encode()
             |> Transaction.Recovered.recover_from()

    good_tx_rlp_items
  end
end
