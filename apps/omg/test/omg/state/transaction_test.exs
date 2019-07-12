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
    - recovery and stateless validation done in `Transaction.Recovered`
    - creation and encoding of raw transactions
    - some basic checks of internal APIs used elsewhere - getting inputs/outputs, spend authorization, hashing, encoding
  """
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.DevCrypto
  alias OMG.State
  alias OMG.State.Transaction
  alias OMG.TestHelper
  alias OMG.Utxo

  require Utxo

  @zero_address OMG.Eth.zero_address()
  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @utxo_positions [{20, 42, 1}, {2, 21, 0}, {1000, 0, 0}, {10_001, 0, 0}]
  @transaction Transaction.new(
                 [{1, 1, 0}, {1, 2, 1}],
                 [{"alicealicealicealice", @eth, 1}, {"carolcarolcarolcarol", @eth, 2}],
                 <<0::256>>
               )

  @empty_signature <<0::size(520)>>
  @no_owner %{priv: <<>>, addr: nil}

  describe "hashing and metadata field" do
    test "create transaction with metadata" do
      tx_with_metadata = Transaction.new(@utxo_positions, [{"Joe Black", @eth, 53}], <<42::256>>)
      tx_without_metadata = Transaction.new(@utxo_positions, [{"Joe Black", @eth, 53}])

      assert Transaction.raw_txhash(tx_with_metadata) != Transaction.raw_txhash(tx_without_metadata)

      assert byte_size(Transaction.raw_txbytes(tx_with_metadata)) >
               byte_size(Transaction.raw_txbytes(tx_without_metadata))
    end

    test "raw transaction hash is invariant" do
      assert Transaction.raw_txhash(@transaction) ==
               Base.decode16!("09645ee9736332be55eaccf9d08ff572a6fa23e2f6dc2aac42dbf09832d8f60e", case: :lower)
    end
  end

  describe "APIs used by the `OMG.State.exec/1`" do
    @tag fixtures: [:alice, :state_alice_deposit, :bob]
    test "using created transaction in child chain", %{alice: alice, bob: bob, state_alice_deposit: state} do
      state = state |> TestHelper.do_deposit(alice, %{amount: 10, currency: @eth, blknum: 2})

      Transaction.new([{1, 0, 0}, {2, 0, 0}], [{bob.addr, @eth, 12}])
      |> DevCrypto.sign([alice.priv, alice.priv])
      |> assert_tx_usable(state)
    end

    @tag fixtures: [:alice, :state_alice_deposit, :bob]
    test "using created transaction with one input in child chain", %{
      alice: alice,
      bob: bob,
      state_alice_deposit: state
    } do
      Transaction.new([{1, 0, 0}], [{bob.addr, @eth, 4}])
      |> DevCrypto.sign([alice.priv, <<>>])
      |> assert_tx_usable(state)
    end

    test "create transaction with different number inputs and outputs" do
      check_input1 = Utxo.position(20, 42, 1)
      output1 = {"Joe Black", @eth, 99}
      check_output2 = %{amount: 99, currency: @eth, owner: "Joe Black"}
      # 1 - input, 1 - output
      tx1_1 = Transaction.new([hd(@utxo_positions)], [output1])
      assert 1 == tx1_1 |> Transaction.get_inputs() |> length()
      assert 1 == tx1_1 |> Transaction.get_outputs() |> length()
      assert [^check_input1 | _] = Transaction.get_inputs(tx1_1)
      assert [^check_output2 | _] = Transaction.get_outputs(tx1_1)
      # 4 - input, 4 - outputs
      tx4_4 = Transaction.new(@utxo_positions, [output1, {"J", @eth, 929}, {"J", @eth, 929}, {"J", @eth, 199}])
      assert 4 == tx4_4 |> Transaction.get_inputs() |> length()
      assert 4 == tx4_4 |> Transaction.get_outputs() |> length()
      assert [^check_input1 | _] = Transaction.get_inputs(tx4_4)
      assert [^check_output2 | _] = Transaction.get_outputs(tx4_4)
    end

    @tag fixtures: [:alice, :bob]
    test "recovering spenders: different signers, one output", %{alice: alice, bob: bob} do
      {:ok, recovered} =
        [{3000, 0, 0}, {3000, 0, 1}]
        |> Transaction.new([{alice.addr, @eth, 10}])
        |> DevCrypto.sign([bob.priv, alice.priv])
        |> Transaction.Signed.encode()
        |> Transaction.Recovered.recover_from()

      assert recovered.spenders == [bob.addr, alice.addr]
    end

    @tag fixtures: [:alice, :bob, :carol]
    test "checks if spenders are authorized", %{alice: alice, bob: bob, carol: carol} do
      authorized_tx = TestHelper.create_recovered([{1, 1, 0, alice}, {1, 3, 0, bob}], @eth, [{bob, 6}, {alice, 4}])

      :ok = Transaction.Recovered.all_spenders_authorized(authorized_tx, [alice.addr, bob.addr])

      {:error, :unauthorized_spent} = Transaction.Recovered.all_spenders_authorized(authorized_tx, [carol.addr])

      {:error, :unauthorized_spent} =
        Transaction.Recovered.all_spenders_authorized(authorized_tx, [alice.addr, carol.addr])
    end

    @tag fixtures: [:alice, :bob]
    test "restrictive spender checks: signature indices correspond to input indices", %{alice: alice, bob: bob} do
      # an additional check on the authorization which might be dropped later - for now we require all inputs to be
      # signed in order, because this is what the contract requires
      authorized_tx = TestHelper.create_recovered([{1, 1, 0, alice}, {1, 3, 0, bob}], @eth, [{bob, 6}, {alice, 4}])

      {:error, :unauthorized_spent} =
        Transaction.Recovered.all_spenders_authorized(authorized_tx, [bob.addr, alice.addr])

      {:error, :unauthorized_spent} =
        Transaction.Recovered.all_spenders_authorized(authorized_tx, [alice.addr, alice.addr, bob.addr])
    end

    @tag fixtures: [:alice, :bob]
    test "signed transaction is valid in all input zeroing combinations", %{
      alice: alice,
      bob: bob
    } do
      [
        {[{1, 2, 3, alice}, {2, 3, 4, bob}], [{alice, @eth, 7}, {bob, @eth, 3}]},
        {[{1, 2, 3, alice}, {0, 0, 0, @no_owner}], [{alice, @eth, 7}, {bob, @eth, 3}]},
        {[{1, 2, 3, alice}, {2, 3, 4, bob}, {0, 0, 0, @no_owner}, {0, 0, 0, @no_owner}],
         [{alice, @eth, 7}, {bob, @eth, 3}]}
      ]
      |> Enum.map(&parametrized_tester/1)
    end

    @tag fixtures: [:alice, :bob]
    test "transaction with 4in/4out is valid", %{alice: alice, bob: bob} do
      [
        {[{1, 2, 3, alice}, {2, 3, 1, alice}, {2, 3, 2, bob}, {3, 3, 4, bob}],
         [{alice, @eth, 7}, {alice, @eth, 3}, {bob, @eth, 7}, {bob, @eth, 3}]}
      ]
      |> Enum.map(&parametrized_tester/1)
    end
  end

  describe "encoding/decoding is done properly" do
    test "Decode raw transaction, a low level encode/decode parity check" do
      {:ok, decoded} = @transaction |> Transaction.raw_txbytes() |> Transaction.decode()
      assert decoded == @transaction
      assert decoded == @transaction |> Transaction.raw_txbytes() |> Transaction.decode!()
    end

    @tag fixtures: [:alice]
    test "decoding malformed signed transaction", %{alice: alice} do
      %Transaction.Signed{sigs: sigs} =
        tx =
        Transaction.new([{1, 0, 0}, {2, 0, 0}], [{alice.addr, @eth, 12}])
        |> DevCrypto.sign([alice.priv, alice.priv])

      [inputs, outputs] = Transaction.raw_txbytes(tx) |> ExRLP.decode()

      assert {:error, :malformed_transaction} = Transaction.Recovered.recover_from(<<192>>)
      assert {:error, :malformed_transaction} = Transaction.Recovered.recover_from(<<0x80>>)
      assert {:error, :malformed_transaction} = Transaction.Recovered.recover_from(<<>>)
      assert {:error, :malformed_transaction} = Transaction.Recovered.recover_from(ExRLP.encode(23))
      assert {:error, :malformed_transaction} = Transaction.Recovered.recover_from(ExRLP.encode([sigs, []]))

      assert {:error, :malformed_signatures} ==
               Transaction.Recovered.recover_from(ExRLP.encode([[<<1>>, <<1>>], inputs, outputs]))

      assert {:error, :malformed_signatures} ==
               Transaction.Recovered.recover_from(ExRLP.encode([<<1>>, inputs, outputs]))

      assert {:error, :malformed_inputs} = Transaction.Recovered.recover_from(ExRLP.encode([sigs, 42, outputs]))
      assert {:error, :malformed_inputs} = Transaction.Recovered.recover_from(ExRLP.encode([sigs, [[1, 2]], outputs]))

      assert {:error, :malformed_inputs} =
               Transaction.Recovered.recover_from(ExRLP.encode([sigs, [[1, 2, 'a']], outputs]))

      assert {:error, :malformed_outputs} = Transaction.Recovered.recover_from(ExRLP.encode([sigs, inputs, 42]))

      assert {:error, :malformed_outputs} =
               Transaction.Recovered.recover_from(ExRLP.encode([sigs, inputs, [[alice.addr, alice.addr]]]))

      assert {:error, :malformed_outputs} =
               Transaction.Recovered.recover_from(ExRLP.encode([sigs, inputs, [[alice.addr, alice.addr, 'a']]]))

      assert {:error, :malformed_metadata} =
               Transaction.Recovered.recover_from(ExRLP.encode([sigs, inputs, outputs, ""]))

      assert {:error, :malformed_metadata} =
               Transaction.Recovered.recover_from(ExRLP.encode([sigs, inputs, outputs, <<0::288>>]))
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
    test "Decoding transaction with gaps in inputs returns error", %{alice: alice} do
      assert {:error, :inputs_contain_gaps} ==
               TestHelper.create_encoded([{0, 0, 0, alice}, {1000, 0, 0, alice}], @eth, [{alice, 100}])
               |> Transaction.Recovered.recover_from()

      assert {:error, :inputs_contain_gaps} ==
               TestHelper.create_encoded(
                 [{1000, 0, 0, alice}, {0, 0, 0, alice}, {2000, 0, 0, alice}],
                 @eth,
                 [{alice, 100}]
               )
               |> Transaction.Recovered.recover_from()

      assert {:ok, _} =
               TestHelper.create_encoded(
                 [{1000, 0, 0, alice}, {2000, 0, 0, alice}, {3000, 0, 0, alice}],
                 @eth,
                 [{alice, 100}]
               )
               |> Transaction.Recovered.recover_from()
    end

    @tag fixtures: [:alice]
    test "Decoding deposit transaction without inputs is successful", %{alice: alice} do
      assert {:ok, _} =
               TestHelper.create_encoded([], @eth, [{alice, 100}])
               |> Transaction.Recovered.recover_from()
    end

    @tag fixtures: [:alice]
    test "Decoding transaction with gaps in outputs returns error", %{alice: alice} do
      no_account = %{addr: @zero_address}

      assert {:error, :outputs_contain_gaps} ==
               TestHelper.create_encoded([{1000, 0, 0, alice}], @eth, [{no_account, 0}, {alice, 100}])
               |> Transaction.Recovered.recover_from()

      assert {:error, :outputs_contain_gaps} ==
               TestHelper.create_encoded(
                 [{1000, 0, 0, alice}],
                 @eth,
                 [{alice, 100}, {no_account, 0}, {alice, 100}]
               )
               |> Transaction.Recovered.recover_from()

      assert {:ok, _} =
               TestHelper.create_encoded(
                 [{1000, 0, 0, alice}],
                 @eth,
                 [{alice, 100}, {alice, 100}, {no_account, 0}, {no_account, 0}]
               )
               |> Transaction.Recovered.recover_from()
    end

    @tag fixtures: [:alice]
    test "Decoding transaction without outputs is successful", %{alice: alice} do
      assert {:ok, _} =
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
    assert {:ok, {_, _, _}, _state} = State.Core.exec(state_core, transaction, :ignore)
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
            }} = Transaction.Recovered.recover_from(encoded_signed_tx)
  end
end
