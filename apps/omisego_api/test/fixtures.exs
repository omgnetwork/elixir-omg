defmodule OmiseGO.API.Fixtures do
  use ExUnitFixtures.FixtureModule

  alias OmiseGO.API.Crypto
  alias OmiseGO.API.State.Core

  import OmiseGO.API.TestHelper

  deffixture(entities, do: entities())

  deffixture(alice(entities), do: entities.alice)
  deffixture(bob(entities), do: entities.bob)
  deffixture(carol(entities), do: entities.carol)

  deffixture(stable_alice(entities), do: entities.stable_alice)
  deffixture(stable_bob(entities), do: entities.stable_bob)

  deffixture state_empty() do
    {:ok, state} = Core.extract_initial_state([], 0, 0, OmiseGO.API.BlockQueue.child_block_interval())
    state
  end

  deffixture state_alice_deposit(state_empty, alice) do
    state_empty
    |> do_deposit(alice, %{amount: 10, currency: Crypto.zero_address(), blknum: 1})
  end

  deffixture state_stable_alice_deposit(state_empty, stable_alice) do
    state_empty
    |> do_deposit(stable_alice, %{amount: 10, currency: Crypto.zero_address(), blknum: 1})
  end
end
