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
    :ok = geth

    Eth.DevHelpers.prepare_env!("../../")
  end

  deffixture token(contract) do
    _ = contract
    root_path = "../../"
    {:ok, [addr | _]} = Ethereumex.HttpClient.eth_accounts()
    {:ok, _, token_addr} = OmiseGO.Eth.DevHelpers.create_new_token(root_path, addr)
    %{address: token_addr}
  end

  deffixture root_chain_contract_config(contract) do
    Application.put_env(:omisego_eth, :contract_addr, contract.contract_addr, persistent: true)
    Application.put_env(:omisego_eth, :authority_addr, contract.authority_addr, persistent: true)
    Application.put_env(:omisego_eth, :txhash_contract, contract.txhash_contract, persistent: true)

    {:ok, started_apps} = Application.ensure_all_started(:omisego_eth)

    on_exit(fn ->
      Application.put_env(:omisego_eth, :contract_addr, "0x0")
      Application.put_env(:omisego_eth, :authority_addr, "0x0")
      Application.put_env(:omisego_eth, :txhash_contract, "0x0")

      started_apps
      |> Enum.reverse()
      |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end)

    :ok
  end

  deffixture token_contract_config(token) do
    Application.put_env(:omisego_eth, :token_addr, token.address, persistent: true)

    {:ok, enc_eth} = OmiseGO.API.Crypto.encode_address(OmiseGO.API.Crypto.zero_address())
    {:ok, path} = OmiseGO.API.TestHelper.write_fee_file(%{enc_eth => 0, token.address => 0})
    default_path = Application.get_env(:omisego_api, :fee_specs_file_path)
    Application.put_env(:omisego_api, :fee_specs_file_path, path, persistent: true)

    on_exit(fn ->
      Application.put_env(:omisego_api, :fee_specs_file_path, default_path)
      Application.put_env(:omisego_eth, :token_addr, "0x0")
    end)

    :ok
  end
end
