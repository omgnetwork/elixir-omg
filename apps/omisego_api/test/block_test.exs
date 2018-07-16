defmodule OmiseGO.API.BlockTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.Block
  alias OmiseGO.API.TestHelper

  @tag fixtures: [:stable_alice, :stable_bob]
  test "block has a correct hash", %{stable_alice: alice, stable_bob: bob} do
    block = %Block{
      transactions: [
        TestHelper.create_recovered([{1, 1, 0, alice}, {1, 2, 1, bob}], OmiseGO.API.Crypto.zero_address(), [
          {alice, 1},
          {bob, 2}
        ])
      ]
    }

    hash = "6bf9be56ea0c58ad2d473f6bb634526371dea358f5a2762a808fb535a4481626" |> Base.decode16!(case: :lower)

    expected = %Block{
      transactions: block.transactions,
      hash: hash
    }

    assert expected == Block.merkle_hash(block)
  end
end
