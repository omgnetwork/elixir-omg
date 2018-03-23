defmodule OmiseGO.API.Fixtures do
  use ExUnitFixtures.FixtureModule

  alias OmiseGO.API.State.Core

  import OmiseGO.API.TestHelper

  deffixture entities do
    %{
      alice: generate_entity(),
      bob: generate_entity(),
      carol: generate_entity(),
    }
  end

  deffixture alice(entities), do: entities.alice
  deffixture bob(entities), do: entities.bob
  deffixture carol(entities), do: entities.carol

  deffixture state_empty() do
    Core.extract_initial_state(1, [])
  end

  deffixture state_alice_deposit(state_empty, alice) do
    state_empty
    |> do_deposit(alice.addr, 10)
  end

end
