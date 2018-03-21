defmodule OmiseGO.Eth.Fixtures do
  use ExUnitFixtures.FixtureModule

  deffixture geth do
    {:ok, exit_fn} = OmiseGO.Eth.geth()
    on_exit(exit_fn)
    :ok
  end

  deffixture contract(geth) do
    _ = geth
    {from, contract_address} = OmiseGO.Eth.TestHelpers.create_new_contract()

    %{
      address: contract_address,
      from: from
    }
  end
end
