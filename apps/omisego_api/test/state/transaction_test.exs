defmodule OmiseGO.API.State.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.State.Transaction

  @signature <<1>> |> List.duplicate(65) |> :binary.list_to_bin

  deffixture transaction do
    %Transaction{
      blknum1: 1,
      txindex1: 1,
      oindex1: 0,
      blknum2: 1,
      txindex2: 2,
      oindex2: 1,
      newowner1: "alicealicealicealice",
      amount1: 1,
      newowner2: "carolcarolcarolcarol",
      amount2: 2,
      fee: 0
    }
  end

  @tag fixtures: [:transaction]
  test "transaction hash is correct", %{transaction: transaction} do
    assert Transaction.hash(transaction) ==
      <<206, 180, 169, 245, 52, 190, 189, 248, 33, 15, 103, 145, 4, 195, 170, 59,
        137, 102, 245, 238, 22, 172, 18, 240, 21, 132, 30, 1, 197, 112, 101, 192>>
  end

  @tag fixtures: [:transaction]
  test "signed transaction hash is correct", %{transaction: transaction} do
    signed = %Transaction.Signed{raw_tx: transaction, sig1: @signature, sig2: @signature}
    expected = <<175, 208, 164, 69, 22, 38, 193, 134, 95, 170, 119, 86, 39, 147, 95, 123, 166,
                91, 185, 190, 80, 98, 29, 44, 143, 195, 28, 143, 188, 155, 136, 149>>

    %Transaction.Signed{hash: actual} = Transaction.Signed.hash(signed)
    assert actual == expected
  end

end
