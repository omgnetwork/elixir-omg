defmodule OmiseGO.API.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.Core
  alias OmiseGO.API.Crypto
  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.TestHelper

  @empty_signature <<0::size(520)>>

  def eth, do: Crypto.zero_address()

  @tag fixtures: [:alice, :bob]
  test "signed transaction is valid in all input zeroing combinations", %{
    alice: alice,
    bob: bob
  } do
    parametrized_tester = fn {input1, input2, spender1, spender2} ->
      raw_tx =
        Transaction.new(
          [input1, input2] |> Enum.map(fn {blknum, txindex, oindex, _} -> {blknum, txindex, oindex} end),
          eth(),
          [{alice, 7}, {bob, 3}] |> Enum.map(fn {newowner, amount} -> {newowner.addr, amount} end)
        )

      encoded_signed_tx = TestHelper.create_encoded([input1, input2], eth(), [{alice, 7}, {bob, 3}])

      assert {:ok,
              %Transaction.Recovered{
                signed_tx: %Transaction.Signed{raw_tx: ^raw_tx},
                spender1: ^spender1,
                spender2: ^spender2
              }} = Core.recover_tx(encoded_signed_tx)
    end

    [
      {{1, 2, 3, alice}, {2, 3, 4, bob}, alice.addr, bob.addr},
      {{1, 2, 3, alice}, {0, 0, 0, %{priv: <<>>}}, alice.addr, nil},
      {{0, 0, 0, %{priv: <<>>}}, {2, 3, 4, bob}, nil, bob.addr}
    ]
    |> Enum.map(parametrized_tester)
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
  test "transaction is not allowed to have input and empty sig", %{alice: alice, bob: bob} do
    full_signed_tx = TestHelper.create_signed([{1, 2, 3, alice}, {2, 3, 4, bob}], eth(), [{alice, 7}])

    missing1 =
      %Transaction.Signed{full_signed_tx | sig1: @empty_signature}
      |> Transaction.Signed.encode()

    missing2 =
      %Transaction.Signed{full_signed_tx | sig2: @empty_signature}
      |> Transaction.Signed.encode()

    partial_signed_tx1 = TestHelper.create_signed([{1, 2, 3, alice}], eth(), [{alice, 7}])

    missing3 =
      %Transaction.Signed{partial_signed_tx1 | sig1: @empty_signature}
      |> Transaction.Signed.encode()

    partial_signed_tx2 = TestHelper.create_signed([{0, 0, 0, %{priv: <<>>}}, {1, 2, 3, alice}], eth(), [{alice, 7}])

    missing4 =
      %Transaction.Signed{partial_signed_tx2 | sig2: @empty_signature}
      |> Transaction.Signed.encode()

    assert {:error, :signature_missing_for_input} == Core.recover_tx(missing1)
    assert {:error, :signature_missing_for_input} == Core.recover_tx(missing2)
    assert {:error, :signature_missing_for_input} == Core.recover_tx(missing3)
    assert {:error, :signature_missing_for_input} == Core.recover_tx(missing4)
  end

  @tag fixtures: [:alice]
  test "transactions with corrupt signatures don't do harm", %{alice: alice} do
    full_signed_tx = TestHelper.create_signed([{1, 2, 3, alice}], eth(), [{alice, 7}])

    corrupt =
      %Transaction.Signed{full_signed_tx | sig1: <<1::size(520)>>}
      |> Transaction.Signed.encode()

    assert {:error, :signature_corrupt} == Core.recover_tx(corrupt)
  end

  @tag fixtures: [:alice, :bob]
  test "transaction is not allowed to have no input and a sig", %{alice: alice, bob: bob} do
    no_input_tx1 = TestHelper.create_encoded([{0, 0, 0, alice}, {2, 3, 4, bob}], eth(), [{alice, 7}])
    no_input_tx2 = TestHelper.create_encoded([{1, 2, 3, alice}, {0, 0, 0, bob}], eth(), [{alice, 7}])
    assert {:error, :input_missing_for_signature} == Core.recover_tx(no_input_tx1)
    assert {:error, :input_missing_for_signature} == Core.recover_tx(no_input_tx2)
  end

  @tag fixtures: [:alice]
  test "transaction is never allowed to have 2 empty inputs", %{alice: alice} do
    double_zero_tx1 =
      TestHelper.create_encoded([{0, 0, 0, %{priv: <<>>}}, {0, 0, 0, %{priv: <<>>}}], eth(), [{alice, 7}])

    double_zero_tx2 = TestHelper.create_encoded([{0, 0, 0, alice}, {0, 0, 0, %{priv: <<>>}}], eth(), [{alice, 7}])
    double_zero_tx3 = TestHelper.create_encoded([{0, 0, 0, %{priv: <<>>}}, {0, 0, 0, alice}], eth(), [{alice, 7}])
    double_zero_tx4 = TestHelper.create_encoded([{0, 0, 0, alice}, {0, 0, 0, alice}], eth(), [{alice, 7}])

    assert {:error, :no_inputs} == Core.recover_tx(double_zero_tx1)
    assert {:error, :no_inputs} == Core.recover_tx(double_zero_tx2)
    assert {:error, :no_inputs} == Core.recover_tx(double_zero_tx3)
    assert {:error, :no_inputs} == Core.recover_tx(double_zero_tx4)
  end
end
