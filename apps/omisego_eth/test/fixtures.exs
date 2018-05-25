defmodule OmiseGO.Eth.Fixtures do
  @moduledoc """
  Contains fixtures for tests that require geth and contract
  """
  use ExUnitFixtures.FixtureModule

  alias OmiseGO.Eth

  deffixture geth do
    Application.ensure_all_started(:erlexec)
    {:ok, exit_fn} = OmiseGO.Eth.dev_geth()
    on_exit(exit_fn)
    :ok
  end

  deffixture contract(geth) do
    _ = geth

    %{contract: contract_address, txhash_contract: txhash, authority_addr: authority} =
      Eth.DevHelpers.prepare_env!("../../")

    %{
      address: contract_address,
      from: authority,
      txhash: txhash
    }
  end
end
