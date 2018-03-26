defmodule OmiseGO.API.BlockTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.Block

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

    signed_tx_hash =
      raw_tx
      |> Transaction.signed(alice.priv, bob.priv)
      |> Transaction.Signed.hash

    recovered_tx =
      %Transaction.Recovered{raw_tx: raw_tx,
        signed_tx_hash: signed_tx_hash,
        spender1: alice.addr,
        spender2: bob.addr
      }

    block = %Block{transactions: [recovered_tx]}

    expected =
      %Block{
        transactions: [recovered_tx],
        hash: <<39, 49, 253, 85, 4, 152, 15, 89, 68, 191, 248, 101, 94, 133,
                166, 205, 152, 186, 3, 97, 5, 27, 75, 135, 36, 207, 221,
                100, 239, 85, 109, 27>>
       }
    assert expected == Block.merkle_hash(block)
  end

end
