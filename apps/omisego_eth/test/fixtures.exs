defmodule OmiseGO.Eth.Fixtures do
  use ExUnitFixtures.FixtureModule

  deffixture geth do
    {:ok, exit_fn} = OmiseGO.Eth.geth()
    on_exit(exit_fn)
    :ok
  end

  deffixture contract(geth) do
    _ = geth
    {from, {txhash, contract_address}} = OmiseGO.Eth.DevHelpers.create_new_contract()

    %{
      address: contract_address,
      from: from,
      txhash: txhash
    }
  end
end
