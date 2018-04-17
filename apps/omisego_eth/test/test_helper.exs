ExUnit.configure(exclude: [requires_geth: true])
ExUnitFixtures.start()
ExUnit.start()

defmodule OmiseGO.Eth.TestHelpers do
  alias OmiseGO.Eth.WaitFor, as: WaitFor

  defp deploy_contract(addr, bytecode, types, args) do
    enc_args = encode_constructor_params(types, args)
    txmap = %{from: addr, data: bytecode <> enc_args, gas: "0x3D0900"}

    {:ok, txhash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    {:ok, %{"contractAddress" => contract_address}} = WaitFor.eth_receipt(txhash, 10_000)
    {txhash, contract_address}
  end

  def create_new_contract do
    _ = Application.ensure_all_started(:ethereumex)
    {:ok, [addr | _]} = Ethereumex.HttpClient.eth_accounts()

    path_project_root = Application.get_env(:omisego_eth, :root_path)

    %{"RootChain" => %{"bytecode" => bytecode}} =
      (path_project_root <> "populus/build/contracts.json") |> File.read!() |> Poison.decode!()

    {addr, deploy_contract(addr, bytecode, [], [])}
  end

  defp encode_constructor_params(args, types) do
    args = for arg <- args, do: cleanup(arg)

    args
    |> ABI.TypeEncoder.encode_raw(types)
    |> Base.encode16(case: :lower)
  end

  defp cleanup("0x" <> hex), do: hex |> String.upcase() |> Base.decode16!()
  defp cleanup(other), do: other
end
