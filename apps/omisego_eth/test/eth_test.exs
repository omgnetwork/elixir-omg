defmodule OmiseGO.EthTest do
  alias OmiseGO.Eth, as: Eth
  alias OmiseGO.Eth.WaitFor, as: WaitFor

  use ExUnitFixtures
  use ExUnit.Case, async: false

  doctest OmiseGO.Eth

  def deploy_contract(addr, bytecode, types, args) do
    enc_args = encode_constructor_params(types, args)
    txmap = %{from: addr, data: bytecode <> enc_args, gas: "0x3D0900"}

    {:ok, txhash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    {:ok, %{"contractAddress" => contract_address}} = WaitFor.eth_receipt(txhash, 10_000)
    contract_address
  end

  def set_new_contract do
    _ = Application.ensure_all_started(:ethereumex)
    {:ok, [addr | _]} = Ethereumex.HttpClient.eth_accounts()

    path_project_root = Application.get_env(:omisego_eth, :root_path)

    %{"RootChain" => %{"bytecode" => bytecode}} =
      (path_project_root <> "populus/build/contracts.json") |> File.read!() |> Poison.decode!()

    {addr, deploy_contract(addr, bytecode, [], [])}
  end

  @first_block %Eth.Transaction{
    root_hash: "0xFEFB8740A301134C7762E38241B59FC8181D982A1DE629F7168622A863E9BCAC",
    gas_price: "0x2D0900",
    nonce: 1
  }

  defp create_first_blocks() do
    {addres, contract} = set_new_contract()
    {:ok, 1} = Eth.get_current_child_block(contract)
    Eth.submit_block(@first_block, addres, contract)
    {:ok, 2} = Eth.get_current_child_block(contract)
    for nonce <- 1..5, do: Eth.submit_block(%{@first_block | nonce: nonce}, addres, contract)
    {:ok, 6} = Eth.get_current_child_block(contract)
    {addres, contract}
  end

  @tag fixtures: [:geth]
  test "child block increment after add block" do
    create_first_blocks()
  end

  @tag fixtures: [:geth]
  test "child not increment number after add wrong nonce" do
    {addres, contract} = create_first_blocks()
    {:ok, current_block} = Eth.get_current_child_block(contract)

    for nonce <- Enum.to_list(1..10) -- [current_block],
        do: Eth.submit_block(%{@first_block | nonce: nonce}, addres, contract)

    {:ok, current_block} = Eth.get_current_child_block(contract)
  end

  @tag fixtures: [:geth]
  test "get_ethereum_heigh return integer" do
    {:ok, number} = Eth.get_ethereum_height()
    assert is_integer(number)
  end

  @tag fixtures: [:geth]
  test "get child chain" do
    {addres, contract} = create_first_blocks()
    {:ok, hash} = Eth.get_chilid_chain(2, contract)
    hash = String.downcase(hash)

    assert String.slice(hash, 0, String.length(@first_block.root_hash)) ==
             String.downcase(@first_block.root_hash)
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
