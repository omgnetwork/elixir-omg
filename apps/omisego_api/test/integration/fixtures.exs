defmodule OmiseGO.API.Integration.Fixtures do
  use ExUnitFixtures.FixtureModule
  use OmiseGO.Eth.Fixtures

  alias OmiseGO.Eth

  import OmiseGO.API.Integration.DepositHelper

  deffixture alice_deposits(alice, token) do
    {:ok, alice_address} = Eth.DevHelpers.import_unlock_fund(alice)
    deposit_blknum = deposit_to_child_chain(alice_address, 10)
    token_deposit_blknum = deposit_to_child_chain(alice_address, 10, token)

    {deposit_blknum, token_deposit_blknum}
  end
end
