defmodule OmiseGO.API.BlockTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.Block
  alias OmiseGO.API.Core
  alias OmiseGO.API.State.Transaction

  @tag fixtures: [:stable_alice, :stable_bob]
  test "block has a correct hash", %{stable_alice: alice, stable_bob: bob} do
    raw_tx = %Transaction{
      blknum1: 1,
      txindex1: 1,
      oindex1: 0,
      blknum2: 1,
      txindex2: 2,
      oindex2: 1,
      newowner1: alice.addr,
      amount1: 1,
      newowner2: bob.addr,
      amount2: 2,
      fee: 0
    }

    encoded_singed_tx =
      raw_tx
      |> Transaction.sign(alice.priv, bob.priv)
      |> Transaction.Signed.encode()

    {:ok, recovered_tx} = Core.recover_tx(encoded_singed_tx)

    block = %Block{transactions: [recovered_tx]}

    expected = %Block{
      transactions: [recovered_tx],
      hash:
        <<133, 111, 138, 167, 92, 2, 81, 74, 248, 14, 203, 120, 82, 125, 24, 224, 
        241, 68, 2, 151, 192, 14, 183, 223, 64, 73, 158, 238, 70, 204, 13, 175>>
    }

    assert expected == Block.merkle_hash(block)
  end
end
