defmodule OmiseGO.Eth.Fixtures do
  use ExUnitFixtures.FixtureModule

  deffixture geth do
    {:ok, exit_fn} = OmiseGO.Eth.geth()
    on_exit(exit_fn)
    :ok
  end

  deffixture contract(geth) do
    {from, contract_addres} = OmiseGO.Eth.TestHelpers.create_new_contract()

    %{
      addres: contract_addres,
      from: from
    }
  end
end
