defmodule OmiseGO.Eth.Fixtures do
  @moduledoc """
  Contains fixtures for tests that require geth and contract
  """
  use ExUnitFixtures.FixtureModule

  alias OmiseGO.Eth

  deffixture geth do
    {:ok, exit_fn} = Eth.DevGeth.start()
    on_exit(exit_fn)
    :ok
  end

  deffixture contract(geth) do
    _ = geth

    %{contract_addr: contract_addr, txhash_contract: txhash} = env = OmiseGO.Eth.DevHelpers.prepare_env!("../../")

    Application.put_env(:omisego_eth, :contract_addr, contract_addr, persistent: true)
    Application.put_env(:omisego_eth, :txhash_contract, txhash, persistent: true)

    on_exit(fn ->
      Application.put_env(:omisego_eth, :contract, nil)
      Application.put_env(:omisego_eth, :txhash_contract, nil)
    end)

    env
  end
end
