defmodule OmiseGO.Eth.DevHelpers do
  @moduledoc """
  Helpers used when setting up development environment and test fixtures, related to contracts and ethereum.
  Run against `geth --dev` and similar.
  """

  alias OmiseGO.API.Crypto
  alias OmiseGO.Eth.WaitFor, as: WaitFor
  import OmiseGO.Eth.Encoding
  alias OmiseGO.Eth

  @lots_of_gas 5_000_000

  @one_hundred_eth trunc(:math.pow(10, 18) * 100)

  def prepare_env!(root_path \\ "./") do
    {:ok, _} = Application.ensure_all_started(:ethereumex)
    {:ok, authority} = create_and_fund_authority_addr()
    {:ok, txhash, contract_addr} = create_new_contract(root_path, authority)
    %{contract_addr: contract_addr, txhash_contract: txhash, authority_addr: authority}
  end

  def create_conf_file(%{contract_addr: contract_addr, txhash_contract: txhash, authority_addr: authority_addr}) do
    """
    use Mix.Config
    config :omisego_eth,
      contract_addr: #{inspect(contract_addr)},
      txhash_contract: #{inspect(txhash)},
      authority_addr: #{inspect(authority_addr)}
    """
  end

  def wait_for_current_child_block(blknum, dev \\ false, timeout \\ 10_000, contract \\ nil) do
    f = fn ->
      {:ok, next_num} = Eth.get_current_child_block(contract)

      case next_num < blknum do
        true ->
          _ = maybe_mine(dev)
          :repeat

        false ->
          {:ok, next_num}
      end
    end

    fn -> WaitFor.repeat_until_ok(f) end |> Task.async() |> Task.await(timeout)
  end

  def create_and_fund_authority_addr do
    {:ok, authority} = Ethereumex.HttpClient.personal_new_account("")
    {:ok, _} = unlock_fund(authority)

    {:ok, authority}
  end

  @doc """
  Will take a map with eth-account information (from &generate_entity/0) and then
  import priv key->unlock->fund with lots of ether on that account
  """
  def import_unlock_fund(%{priv: account_priv, addr: account_addr} = _account) do
    account_priv_enc = Base.encode16(account_priv)
    {:ok, account_enc} = Crypto.encode_address(account_addr)

    {:ok, ^account_enc} = Ethereumex.HttpClient.personal_import_raw_key(account_priv_enc, "")
    {:ok, _} = unlock_fund(account_enc)

    {:ok, account_enc}
  end

  def deposit(value, from, contract \\ nil) do
    contract = contract || Application.get_env(:omisego_eth, :contract_addr)
    contract_transact(from, nil, value, contract, "deposit()", [])
  end

  def deposit_blknum_from_receipt(receipt) do
    [{_, deposit_blknum, _, _}] = filter_receipt_events(receipt["logs"], "Deposit(address,uint256,address,uint256)")
    deposit_blknum
  end

  @spec filter_receipt_events([%{topics: [binary], data: binary()}], binary) :: [tuple]
  def filter_receipt_events(receipt_logs, signature) do
    topic = signature |> OmiseGO.API.Crypto.hash() |> Base.encode16(case: :lower)
    topic = "0x" <> topic

    decode = fn %{"data" => "0x" <> data} ->
      signature
      |> ABI.decode(Base.decode16!(data, case: :lower))
      |> List.to_tuple()
    end

    receipt_logs
    |> Enum.filter(&(topic in &1["topics"]))
    |> Enum.map(decode)
  end

  def deposit_token(from, token, amount, contract \\ nil) do
    contract = contract || Application.get_env(:omisego_eth, :contract_addr)
    signature = "depositFrom(address,address,uint256)"
    contract_transact_sync!(from, nil, nil, contract, signature, [cleanup(from), cleanup(token), amount])
  end

  def token_mint(owner, amount, token) do
    {:ok, [from | _]} = Ethereumex.HttpClient.eth_accounts()
    contract_transact_sync!(from, nil, nil, token, "mint(address,uint256)", [cleanup(owner), amount])
  end

  def token_transfer(from, owner, amount, token) do
    contract_transact_sync!(from, nil, nil, token, "transfer(address,uint256)", [cleanup(owner), amount])
  end

  def token_approve(from, spender, amount, token) do
    contract_transact_sync!(from, nil, nil, token, "approve(address,uint256)", [cleanup(spender), amount])
  end

  def token_balance_of(owner, token) do
    {:ok, {balance}} = Eth.call_contract(token, "balanceOf(address)", [cleanup(owner)], [{:uint, 256}])
    {:ok, balance}
  end

  def add_token(token, contract \\ nil) do
    contract = contract || Application.get_env(:omisego_eth, :contract_addr)
    {:ok, [from | _]} = Ethereumex.HttpClient.eth_accounts()
    signature = "addToken(address)"
    args = [token]
    contract_transact_sync!(from, nil, nil, contract, signature, args)
  end

  def has_token(token, contract \\ nil) do
    contract = contract || Application.get_env(:omisego_eth, :contract_addr)
    {:ok, {has_token}} = Eth.call_contract(contract, "hasToken(address)", [cleanup(token)], [:bool])
    {:ok, has_token}
  end

  def challenge_exit(cutxopo, eutxoindex, txbytes, proof, sigs, from, contract \\ nil) do
    signature = "challengeExit(uint256,uint256,bytes,bytes,bytes)"
    args = [cutxopo, eutxoindex, txbytes, proof, sigs]
    contract_transact(from, nil, nil, contract, signature, args)
  end

  def mine_eth_dev_block do
    {:ok, [addr | _]} = Ethereumex.HttpClient.eth_accounts()
    txmap = %{from: addr, to: addr, value: "0x1"}
    {:ok, txhash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    {:ok, _receipt} = WaitFor.eth_receipt(txhash, 1_000)
  end

  def create_new_contract(path_project_root, addr) do
    bytecode = get_bytecode!(path_project_root, "RootChain")
    deploy_contract(addr, bytecode, [], [])
  end

  def create_new_token(path_project_root, addr) do
    bytecode = get_bytecode!(path_project_root, "MintableToken")
    deploy_contract(addr, bytecode, [], [])
  end

  # private

  defp unlock_fund(account_enc) do
    {:ok, true} = Ethereumex.HttpClient.personal_unlock_account(account_enc, "", 0)

    {:ok, [eth_source_address | _]} = Ethereumex.HttpClient.eth_accounts()
    txmap = %{from: eth_source_address, to: account_enc, value: encode_eth_rpc_unsigned_int(@one_hundred_eth)}
    {:ok, tx_fund} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    WaitFor.eth_receipt(tx_fund, 10_000)
  end

  defp maybe_mine(false), do: :noop
  defp maybe_mine(true), do: mine_eth_dev_block()

  defp deploy_contract(addr, bytecode, types, args) do
    enc_args = encode_constructor_params(types, args)
    txmap = %{from: addr, data: bytecode <> enc_args, gas: "0x4FF2D9"}

    {:ok, txhash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    {:ok, %{"contractAddress" => contract_address, "status" => "0x1"}} = WaitFor.eth_receipt(txhash, 10_000)
    {:ok, txhash, contract_address}
  end

  defp contract_transact(from, nonce, value, to, signature, args, gas \\ @lots_of_gas) do
    data = encode_tx_data(signature, args)

    put_if_has_value = fn
      map, _key, nil -> map
      map, key, value -> Map.put(map, key, encode_eth_rpc_unsigned_int(value))
    end

    txmap =
      %{from: from, to: to, data: "0x" <> data, gas: encode_eth_rpc_unsigned_int(gas)}
      |> put_if_has_value.(:nonce, nonce)
      |> put_if_has_value.(:value, value)

    {:ok, _txhash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
  end

  defp contract_transact_sync!(from, nonce, value, to, signature, args, gas \\ @lots_of_gas) do
    {:ok, txhash} = contract_transact(from, nonce, value, to, signature, args, gas)
    {:ok, %{"status" => "0x1"}} = WaitFor.eth_receipt(txhash, 10_000)
  end

  defp get_bytecode!(path_project_root, contract_name) do
    %{^contract_name => %{"bytecode" => bytecode}} =
      path_project_root
      |> read_contracts_json!()
      |> Poison.decode!()

    bytecode
  end

  defp read_contracts_json!(path_project_root) do
    case File.read(Path.join(path_project_root, "populus/build/contracts.json")) do
      {:ok, contracts_json} ->
        contracts_json

      {:error, reason} ->
        raise(
          RuntimeError,
          "populus/build/contracts.json not read because #{reason}, try running mix deps.compile plasma_contracts"
        )
    end
  end

  defp encode_tx_data(signature, args) do
    args = args |> Enum.map(&cleanup/1)

    signature
    |> ABI.encode(args)
    |> Base.encode16()
  end

  defp encode_constructor_params(args, types) do
    args = for arg <- args, do: cleanup(arg)

    args
    |> ABI.TypeEncoder.encode_raw(types)
    |> Base.encode16(case: :lower)
  end

  defp cleanup("0x" <> hex), do: hex |> String.upcase() |> Base.decode16!()
  defp cleanup(raw), do: raw
end
