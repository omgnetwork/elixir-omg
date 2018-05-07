defmodule OmiseGO.Eth.DevHelpers do
  alias OmiseGO.Eth.WaitFor, as: WaitFor
  import OmiseGO.Eth.Encoding

  @moduledoc """
  Helpers used in MIX_ENV dev and test
  """

  def prepare_dev_env, do: do_prepare("dev")

  def prepare_test_env, do: do_prepare("test")

  defp do_prepare(env) do
    {:ok, contract_address, txhash, authority} = prepare_env("./")
    write_conf_file(env, contract_address, txhash, authority)
  end

  def prepare_env(root_path) do
    _ = Application.ensure_all_started(:ethereumex)
    {:ok, authority} = create_and_fund_authority_addr()
    {_, {txhash, contract_address}} = create_new_contract(root_path, authority)
    {:ok, contract_address, txhash, authority}
  end

  def wait_for_current_child_block(blknum, dev \\ false, timeout \\ 10_000) do
    f = fn() ->
      {:ok, next_num} = OmiseGO.Eth.get_current_child_block()
      case next_num < blknum do
        true ->
          _ = maybe_mine(dev)
          :repeat
        false ->
          {:ok, next_num}
      end
    end
    fn() -> WaitFor.repeat_until_ok(f) end
    |> Task.async |> Task.await(timeout)
  end

  def create_and_fund_authority_addr do
    {:ok, [addr | _]} = Ethereumex.HttpClient.eth_accounts()
    {:ok, authority} = Ethereumex.HttpClient.personal_new_account("")
    {:ok, true} = Ethereumex.HttpClient.personal_unlock_account(authority, "", 0)
    txmap = %{from: addr, to: authority, value: "0x99999999999999999999999"}
    {:ok, tx_fund} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    {:ok, _receipt} = WaitFor.eth_receipt(tx_fund, 10_000)
    {:ok, authority}
  end

  @doc """
  Will take a map with eth-account information (from &generate_entity/0) and then
  import priv key->unlock->fund with lots of ether on that account
  """
  def import_unlock_fund(%{priv: account_priv, addr: account_addr} = _account) do

    account_priv_enc = Base.encode16(account_priv)
    account_enc = "0x" <> Base.encode16(account_addr, case: :lower)

    {:ok, ^account_enc} = Ethereumex.HttpClient.personal_import_raw_key(account_priv_enc, "")
    {:ok, true} = Ethereumex.HttpClient.personal_unlock_account(account_enc, "", 0)

    {:ok, [eth_source_address | _]} = Ethereumex.HttpClient.eth_accounts()
    txmap = %{from: eth_source_address, to: account_enc, value: "0x99999999999999999999999"}
    {:ok, tx_fund} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    {:ok, _} = WaitFor.eth_receipt(tx_fund)

    {:ok, account_enc}
  end

  defp maybe_mine(false), do: :noop
  defp maybe_mine(true) do
    {:ok, [addr | _]} = Ethereumex.HttpClient.eth_accounts()
    txmap = %{from: addr, to: addr, value: "0x1"}
    {:ok, txhash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    {:ok, _receipt} = WaitFor.eth_receipt(txhash, 1_000)
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
      root_path: "../../"\
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

  def deposit(value, nonce, from \\ nil, contract \\ nil) do
    contract = contract || Application.get_env(:omisego_eth, :contract)
    from = from || Application.get_env(:omisego_eth, :authority_addr)

    data =
      "deposit()"
      |> ABI.encode([])
      |> Base.encode16()

    gas = 100_000

    Ethereumex.HttpClient.eth_send_transaction(%{
      from: from,
      to: contract,
      gas: encode_eth_rpc_unsigned_int(gas),
      gasPrice: encode_eth_rpc_unsigned_int(21_000_000_000),
      value: encode_eth_rpc_unsigned_int(value),
      data: "0x#{data}",
      nonce: (if nonce == 0, do: "0x0", else: encode_eth_rpc_unsigned_int(nonce))
    })
  end

  def deposit_height_from_receipt(receipt) do
    %{"logs" => [%{"data" => logs_data}]} = receipt
    <<"0x", _::size(512), _::size(512), deposit_height_enc::binary>> = logs_data
    {deposit_height, ""} = Integer.parse(deposit_height_enc, 16)
    deposit_height
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
