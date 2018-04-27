defmodule OmiseGO.Eth.Fixtures do
  use ExUnitFixtures.FixtureModule

  deffixture geth do
    {:ok, exit_fn} = OmiseGO.Eth.dev_geth()
    on_exit(exit_fn)
    :ok
  end

  deffixture contract(geth) do
    _ = geth
    {:ok, contract_address, txhash, authority} = OmiseGO.Eth.DevHelpers.prepare_env("../../")
    %{
      address: contract_address,
      from: authority,
      txhash: txhash
    }
  end
end
