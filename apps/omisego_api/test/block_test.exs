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
      cur12: Transaction.zero_address(),
      newowner1: alice.addr,
      amount1: 1,
      newowner2: bob.addr,
      amount2: 2
    }

    encoded_singed_tx =
      raw_tx
      |> Transaction.sign(alice.priv, bob.priv)
      |> Transaction.Signed.encode()

    {:ok, recovered_tx} = Core.recover_tx(encoded_singed_tx)

    block = %Block{transactions: [recovered_tx]}

    hash = "6bf9be56ea0c58ad2d473f6bb634526371dea358f5a2762a808fb535a4481626" |> Base.decode16!(case: :lower)

    expected = %Block{
      transactions: [recovered_tx],
      hash: hash
    }

    assert expected == Block.merkle_hash(block)
  end
end
