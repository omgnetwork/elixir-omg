defmodule OmiseGO.API.Fixtures do
  use ExUnitFixtures.FixtureModule

  alias OmiseGO.API.State.Core

  import OmiseGO.API.TestHelper

  @child_block_interval 1000

  deffixture entities do
    %{
      alice: generate_entity(),
      bob: generate_entity(),
      carol: generate_entity(),

      # Deterministic entities. Use only when truly needed.
      stable_alice: %{
        priv:
          <<54, 43, 207, 67, 140, 160, 190, 135, 18, 162, 70, 120, 36, 245, 106, 165, 5, 101, 183,
            55, 11, 117, 126, 135, 49, 50, 12, 228, 173, 219, 183, 175>>,
        addr:
          <<59, 159, 76, 29, 210, 110, 11, 229, 147, 55, 59, 29, 54, 206, 226, 0, 140, 190, 184,
            55>>
      },
      stable_bob: %{
        priv:
          <<208, 253, 134, 150, 198, 155, 175, 125, 158, 156, 21, 108, 208, 7, 103, 242, 9, 139,
            26, 140, 118, 50, 144, 21, 226, 19, 156, 2, 210, 97, 84, 128>>,
        addr:
          <<207, 194, 79, 222, 88, 128, 171, 217, 153, 41, 195, 239, 138, 178, 227, 16, 72, 173,
            118, 35>>
      }
    }
  end

  deffixture(alice(entities), do: entities.alice)
  deffixture(bob(entities), do: entities.bob)
  deffixture(carol(entities), do: entities.carol)

  deffixture(stable_alice(entities), do: entities.stable_alice)
  deffixture(stable_bob(entities), do: entities.stable_bob)

  deffixture state_empty() do
    Core.extract_initial_state([], 0, 0, @child_block_interval)
  end

  deffixture state_alice_deposit(state_empty, alice) do
    state_empty
    |> do_deposit(alice, %{amount: 10, blknum: 1})
  end

  deffixture state_stable_alice_deposit(state_empty, stable_alice) do
    state_empty
    |> do_deposit(stable_alice, %{amount: 10, blknum: 1})
  end
end
