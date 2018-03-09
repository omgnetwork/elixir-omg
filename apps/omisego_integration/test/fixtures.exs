defmodule HonteD.Integration.Fixtures do
  use ExUnitFixtures.FixtureModule

  alias HonteD.Integration

  deffixture homedir() do
    Integration.homedir()
  end

  deffixture tendermint(homedir, honted) do
    :ok = honted # prevent warnings
    {:ok, exit_fn} = Integration.tendermint(homedir)
    on_exit exit_fn
    :ok
  end

  deffixture honted() do
    {:ok, exit_fn} = Integration.honted()
    on_exit exit_fn
    :ok
  end

  deffixture geth() do
    {:ok, exit_fn} = Integration.geth()
    on_exit exit_fn
    :ok
  end

end
