defmodule HonteD.Integration.Contract do
  @moduledoc """
  Helper for staking contract operations in integration/tests/dev.
  """
  alias HonteD.Integration.WaitFor, as: WaitFor

  @doc """
  Deploy OMG token and staking contracts on Ethereum chain. Useful in :dev and :test environments.
  """
  def deploy(epoch_length, maturity_margin, max_validators) do
    path = get_path_to_project_root()
    _ = Application.ensure_all_started(:ethereumex)
    token_bc = File.read!(path <> "contracts/omg_token_bytecode.hex")
    staking_bc = staking_bytecode(path <> "populus/build/contracts.json")
    {:ok, [addr | _]} = Ethereumex.HttpClient.eth_accounts()
    {:ok, token_address} = deploy_contract(addr, token_bc, [], [])
    {:ok, staking_address} = deploy_contract(addr, staking_bc,
      [epoch_length, maturity_margin, token_address, max_validators],
      [{:uint, 256}, {:uint, 256}, :address, {:uint, 256}])
    {:ok, token_address, staking_address}
  end

  def approve(token, addr, benefactor, amount) do
    transact("approve(address,uint256)", [cleanup(benefactor), amount], addr, token)
  end

  def deposit(staking, addr, amount) do
    transact("deposit(uint256)", [amount], addr, staking)
  end

  def join(staking, addr, tm_pubkey) when bit_size(tm_pubkey) == 512 do
    transact("join(bytes32)", [tm_pubkey |> Base.decode16!], addr, staking)
  end

  def mint_omg(token, target, amount) do
    transact("mint(address,uint)", [cleanup(target), amount], target, token)
  end

  def transact(signature, args, from, contract, timeout \\ 10_000) do
    data =
      signature
      |> ABI.encode(args)
      |> Base.encode16
    gas = "0x3D0900"
    {:ok, txhash} =
      Ethereumex.HttpClient.eth_send_transaction(%{from: from, to: contract, data: "0x#{data}", gas: gas})
    {:ok, _receipt} = WaitFor.eth_receipt(txhash, timeout)
  end

  defp deploy_contract(addr, bytecode, types, args) do
    enc_args = encode_constructor_params(types, args)
    four_mil = "0x3D0900"
    txmap = %{from: addr, data: "0x" <> bytecode <> enc_args, gas: four_mil}
    {:ok, txhash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    {:ok, receipt} = WaitFor.eth_receipt(txhash, 10_000)
    %{"contractAddress" => contract_address} = receipt
    {:ok, contract_address}
  end

  defp encode_constructor_params(args, types) do
    args = for arg <- args, do: cleanup(arg)
    args
    |> ABI.TypeEncoder.encode_raw(types)
    |> Base.encode16(case: :lower)
  end

  defp cleanup("0x" <> hex), do: hex |> String.upcase |> Base.decode16!
  defp cleanup(other), do: other

  defp staking_bytecode(path) do
    %{"HonteStaking" => %{"bytecode" => bytecode}} =
      path
      |> File.read!()
      |> Poison.decode!()
    String.replace(bytecode, "0x", "")
  end

  # In runtime working directory depends on the way application was started.
  # `mix test` sets working directory to $ROOT/apps/$APP_CURRENTLY_BEING_TESTED/
  def get_path_to_project_root do
    Application.get_env(:honted_integration, :relative_path_to_root, "")
  end
end
