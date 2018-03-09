defmodule OmiseGO.Integration.Fixtures do
  use ExUnitFixtures.FixtureModule

  alias OmiseGO.Integration

  deffixture homedir() do
    Integration.homedir()
  end

  deffixture tendermint(homedir, omisego) do
    :ok = omisego # prevent warnings
    {:ok, exit_fn} = Integration.tendermint(homedir)
    on_exit exit_fn
    :ok
  end

  deffixture omisego() do
    {:ok, exit_fn} = Integration.omisego()
    on_exit exit_fn
    :ok
  end

  deffixture geth() do
    {:ok, exit_fn} = Integration.geth()
    on_exit exit_fn
    :ok
  end

end
