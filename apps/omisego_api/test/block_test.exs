defmodule OmiseGO.API.BlockTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.Block
  alias OmiseGO.API.Core

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
        <<39, 49, 253, 85, 4, 152, 15, 89, 68, 191, 248, 101, 94, 133, 166, 205, 152, 186, 3, 97, 5, 27, 75, 135, 36,
          207, 221, 100, 239, 85, 109, 27>>
    }

    assert expected == Block.merkle_hash(block)
  end
end
