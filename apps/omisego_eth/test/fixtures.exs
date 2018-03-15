defmodule OmiseGO.Eth.Fixtures do
  use ExUnitFixtures.FixtureModule

  deffixture geth() do
    {:ok, exit_fn} = OmiseGO.Eth.geth()
    on_exit(exit_fn)
    :ok
  end
end
