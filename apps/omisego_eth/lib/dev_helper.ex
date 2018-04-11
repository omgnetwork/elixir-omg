defmodule OmiseGO.Eth.DevHelpers do
  alias OmiseGO.Eth.WaitFor, as: WaitFor

  def prep_dev_env do
    {addr, {txhash, contract_address}} = create_new_contract("./")
    body =
      """
      use Mix.Config
      # File is automatically generated, don't edit!
      # To deploy contract and fill values below, run:
      # mix run --no-start -e 'OmiseGO.Eth.DevHelpers.prep_dev_env()'

      config :omisego_eth,
        contract: #{inspect contract_address},
        txhash_contract: #{inspect txhash},
        omg_addr: #{inspect addr},
        root_path: "../../"
      """
    {:ok, file} = File.open("apps/omisego_eth/config/dev.exs", [:write])
    IO.puts(file, body)
  end

  defp deploy_contract(addr, bytecode, types, args) do
    enc_args = encode_constructor_params(types, args)
    txmap = %{from: addr, data: bytecode <> enc_args, gas: "0x3D0900"}

    {:ok, txhash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    {:ok, %{"contractAddress" => contract_address}} = WaitFor.eth_receipt(txhash, 10_000)
    {txhash, contract_address}
  end

  def mine_eth_dev_block do
    {:ok, [addr | _]} = Ethereumex.HttpClient.eth_accounts()
    txmap = %{from: addr, to: addr, value: "0x1"}
    {:ok, txhash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    {:ok, _receipt} = WaitFor.eth_receipt(txhash, 1_000)
  end

  def create_new_contract do
    path_project_root = Application.get_env(:omisego_eth, :root_path)
    create_new_contract(path_project_root)
  end

  def create_new_contract(path_project_root) do
    _ = Application.ensure_all_started(:ethereumex)
    {:ok, [addr | _]} = Ethereumex.HttpClient.eth_accounts()

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
