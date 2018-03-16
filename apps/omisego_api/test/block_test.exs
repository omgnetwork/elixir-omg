defmodule OmiseGO.API.BlockTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.Block

  test "block has a correct hash" do
    tx = %Transaction{
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
    sig = <<1>> |> List.duplicate(65) |> :binary.list_to_bin
    signed_tx = %Transaction.Signed{raw_tx: tx, sig1: sig, sig2: sig} |> Transaction.Signed.hash
    block = %Block{transactions: [signed_tx]}
    expected =
      %Block{
        transactions: [signed_tx],
        hash: <<187, 156, 163, 31, 125, 99, 105, 127, 178, 172, 123, 159, 141, 169, 117,
                101, 52, 63, 43, 9, 252, 123, 229, 124, 43, 188, 200, 1, 225, 193, 203, 63>>
       }
    assert expected == Block.merkle_hash(block)
  end

end
