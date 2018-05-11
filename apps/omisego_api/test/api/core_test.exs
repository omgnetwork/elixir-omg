defmodule OmiseGO.API.Api.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.Core
  alias OmiseGO.API.TestHelper

  @empty_signature <<0::size(520)>>

  defp create_encoded(inputs, outputs, fee \\ 0) do
    {signed_tx, raw_tx} = TestHelper.create_signed(inputs, outputs, fee)

    encoded_signed_tx = Transaction.Signed.encode(signed_tx)

    {encoded_signed_tx, raw_tx}
  end

  @tag fixtures: [:alice, :bob]
  test "signed transaction is valid in all input zeroing combinations", %{
    alice: alice,
    bob: bob
  } do
    parametrized_tester = fn {input1, input2, spender1, spender2} ->
      {encoded_signed_tx, raw_tx} = create_encoded([input1, input2], [{alice, 7}, {bob, 3}], 1)

      assert {:ok,
              %Transaction.Recovered{
                raw_tx: ^raw_tx,
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
    {encoded_signed_tx, _} = create_encoded([{1, 2, 3, alice}, {2, 3, 4, bob}], [{alice, 7}])
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
  test "transaction is not allowed to have input and empty sig", %{alice: alice, bob: bob} do
    {full_signed_tx, _} = TestHelper.create_signed([{1, 2, 3, alice}, {2, 3, 4, bob}], [{alice, 7}])

    missing1 =
      %Transaction.Signed{full_signed_tx | sig1: @empty_signature}
      |> Transaction.Signed.encode()

    missing2 =
      %Transaction.Signed{full_signed_tx | sig2: @empty_signature}
      |> Transaction.Signed.encode()

    {partial_signed_tx1, _} = TestHelper.create_signed([{1, 2, 3, alice}], [{alice, 7}])

    missing3 =
      %Transaction.Signed{partial_signed_tx1 | sig1: @empty_signature}
      |> Transaction.Signed.encode()

    {partial_signed_tx2, _} = TestHelper.create_signed([{0, 0, 0, %{priv: <<>>}}, {1, 2, 3, alice}], [{alice, 7}])

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
    {full_signed_tx, _} = TestHelper.create_signed([{1, 2, 3, alice}], [{alice, 7}])

    corrupt =
      %Transaction.Signed{full_signed_tx | sig1: <<1::size(520)>>}
      |> Transaction.Signed.encode()

    assert {:error, :signature_corrupt} == Core.recover_tx(corrupt)
  end

  @tag fixtures: [:alice, :bob]
  test "transaction is not allowed to have no input and a sig", %{alice: alice, bob: bob} do
    {no_input_tx1, _} = create_encoded([{0, 0, 0, alice}, {2, 3, 4, bob}], [{alice, 7}])
    {no_input_tx2, _} = create_encoded([{1, 2, 3, alice}, {0, 0, 0, bob}], [{alice, 7}])
    assert {:error, :input_missing_for_signature} == Core.recover_tx(no_input_tx1)
    assert {:error, :input_missing_for_signature} == Core.recover_tx(no_input_tx2)
  end

  @tag fixtures: [:alice]
  test "transaction is never allowed to have 2 empty inputs", %{alice: alice} do
    {double_zero_tx1, _} = create_encoded([{0, 0, 0, %{priv: <<>>}}, {0, 0, 0, %{priv: <<>>}}], [{alice, 7}])
    {double_zero_tx2, _} = create_encoded([{0, 0, 0, alice}, {0, 0, 0, %{priv: <<>>}}], [{alice, 7}])
    {double_zero_tx3, _} = create_encoded([{0, 0, 0, %{priv: <<>>}}, {0, 0, 0, alice}], [{alice, 7}])
    {double_zero_tx4, _} = create_encoded([{0, 0, 0, alice}, {0, 0, 0, alice}], [{alice, 7}])

    assert {:error, :no_inputs} == Core.recover_tx(double_zero_tx1)
    assert {:error, :no_inputs} == Core.recover_tx(double_zero_tx2)
    assert {:error, :no_inputs} == Core.recover_tx(double_zero_tx3)
    assert {:error, :no_inputs} == Core.recover_tx(double_zero_tx4)
  end
end
