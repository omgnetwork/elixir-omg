defmodule OmiseGO.Eth.DevHelpers do
  alias OmiseGO.Eth.WaitFor, as: WaitFor

  @moduledoc """
  Collection of helpers used in MIX_ENV dev and test
  """

  def prepare_dev_env do
    {:ok, contract_address, txhash, authority} = prepare_env("./")
    write_conf_file("dev", contract_address, txhash, authority)
  end

  def prepare_env(root_path) do
    _ = Application.ensure_all_started(:ethereumex)
    {:ok, authority} = create_and_fund_authority_addr()
    {_, {txhash, contract_address}} = create_new_contract(root_path, authority)
    {:ok, contract_address, txhash, authority}
  end

  def create_and_fund_authority_addr do
    {:ok, [addr | _]} = Ethereumex.HttpClient.eth_accounts()
    {:ok, authority} = Ethereumex.HttpClient.personal_new_account("")
    {:ok, true} = Ethereumex.HttpClient.personal_unlock_account(authority, "", 60 * 60 * 24 * 7)
    txmap = %{from: addr, to: authority, value: "0x99999999999999999999999"}
    {:ok, tx_fund} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    {:ok, _receipt} = WaitFor.eth_receipt(tx_fund, 10_000)
    {:ok, authority}
  end

  defp write_conf_file(mix_env, contract_address, txhash, authority) do
    body =
      """
      use Mix.Config
      # File is automatically generated, don't edit!
      # To deploy contract and fill values below, run:
      # mix run --no-start -e 'OmiseGO.Eth.DevHelpers.prepare_dev_env()'

      config :omisego_eth,
      contract: #{inspect contract_address},
      txhash_contract: #{inspect txhash},
      authority_addr: #{inspect authority},
      root_path: "../../"
      """
    {:ok, file} = File.open("apps/omisego_eth/config/#{mix_env}.exs", [:write])
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
    _ = Application.ensure_all_started(:ethereumex)
    {:ok, [addr | _]} = Ethereumex.HttpClient.eth_accounts()
    txmap = %{from: addr, to: addr, value: "0x1"}
    {:ok, txhash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    {:ok, _receipt} = WaitFor.eth_receipt(txhash, 1_000)
  end

  def create_new_contract(path_project_root, addr) do
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
