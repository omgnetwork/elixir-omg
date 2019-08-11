# Copyright 2019 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.Eth.DevHelpers do
  @moduledoc """
  Helpers used when setting up development environment and test fixtures, related to contracts and ethereum.
  Run against `geth --dev` and similar.
  """

  alias OMG.Eth
  alias OMG.Eth.WaitFor

  import Eth.Encoding, only: [to_hex: 1, from_hex: 1, int_from_hex: 1]

  require Logger

  @one_hundred_eth trunc(:math.pow(10, 18) * 100)

  # about 4 Ethereum blocks on "realistic" networks, use to timeout synchronous operations in demos on testnets
  # NOTE: such timeout works only in dev setting; on mainnet one must track its transactions carefully
  @about_4_blocks_time 60_000

  @passphrase "ThisIsATestnetPassphrase"

  @doc """
  Prepares the developer's environment with respect to the root chain contract and its configuration within
  the application.

   - `root_path` should point to `elixir-omg` root or wherever where `./_build/contracts` holds the compiled contracts
  """
  def prepare_env!(opts \\ [], exit_period_seconds \\ nil) do
    opts = Keyword.merge([root_path: "./"], opts)
    %{root_path: root_path} = Enum.into(opts, %{})

    exit_period_seconds = get_exit_period(exit_period_seconds)

    with {:ok, _} <- Application.ensure_all_started(:ethereumex),
         {:ok, authority} <- create_and_fund_authority_addr(opts),
         {:ok, deployer_addr} <- get_deployer_address(opts),
         {:ok, txhash, contract_addr} <- Eth.Deployer.create_new(OMG.Eth.RootChain, root_path, deployer_addr),
         {:ok, _} <-
           Eth.RootChainHelper.init(exit_period_seconds, authority, contract_addr) |> Eth.DevHelpers.transact_sync!() do
      %{contract_addr: contract_addr, txhash_contract: txhash, authority_addr: authority}
    else
      {:error, :econnrefused} = error ->
        Logger.error("It seems that Ethereum instance is not running. Check README.md")
        error

      other ->
        other
    end
  end

  def create_conf_file(%{contract_addr: contract_addr, txhash_contract: txhash, authority_addr: authority_addr}) do
    """
    use Mix.Config
    config :omg_eth,
      contract_addr: #{inspect(to_hex(contract_addr))},
      txhash_contract: #{inspect(to_hex(txhash))},
      authority_addr: #{inspect(to_hex(authority_addr))}
    """
  end

  @doc """
  Will take a map with eth-account information (from &generate_entity/0) and then
  import priv key->unlock->fund with lots of ether on that account
  """
  def import_unlock_fund(%{priv: account_priv}, opts \\ []) do
    account_priv_enc = Base.encode16(account_priv)

    {:ok, account_enc} = create_account_from_secret(OMG.Eth.backend(), account_priv_enc, @passphrase)
    {:ok, _} = fund_address_from_faucet(account_enc, opts)

    {:ok, from_hex(account_enc)}
  end

  @doc """
  Use with contract-transacting functions that return {:ok, txhash}, e.g. `Eth.Token.mint`, for synchronous waiting
  for mining of a successful result
  """
  @spec transact_sync!({:ok, Eth.hash()}) :: {:ok, map}
  def transact_sync!({:ok, txhash} = _transaction_submission_result) when byte_size(txhash) == 32 do
    {:ok, %{"status" => "0x1"} = result} = WaitFor.eth_receipt(txhash, @about_4_blocks_time)
    {:ok, result |> Map.update!("blockNumber", &int_from_hex(&1))}
  end

  @doc """
  Uses `transact_sync!` for synchronous deploy-transaction sending and extracts important data from the receipt
  """
  @spec deploy_sync!({:ok, Eth.hash()}) :: {:ok, Eth.hash(), Eth.address()}
  def deploy_sync!({:ok, txhash} = transaction_submission_result) do
    {:ok, %{"contractAddress" => contract, "status" => "0x1"}} = transact_sync!(transaction_submission_result)
    {:ok, txhash, from_hex(contract)}
  end

  def wait_for_root_chain_block(awaited_eth_height, timeout \\ 600_000) do
    f = fn ->
      {:ok, eth_height} = Eth.get_ethereum_height()

      if eth_height < awaited_eth_height, do: :repeat, else: {:ok, eth_height}
    end

    fn -> WaitFor.repeat_until_ok(f) end |> Task.async() |> Task.await(timeout)
  end

  def wait_for_next_child_block(blknum, timeout \\ 10_000, contract \\ nil) do
    f = fn ->
      {:ok, next_num} = Eth.RootChain.get_next_child_block(contract)

      if next_num < blknum, do: :repeat, else: {:ok, next_num}
    end

    fn -> WaitFor.repeat_until_ok(f) end |> Task.async() |> Task.await(timeout)
  end

  def create_account_from_secret(:geth, secret, passphrase) do
    {:ok, _} = Ethereumex.HttpClient.request("personal_importRawKey", [secret, passphrase], [])
  end

  def create_account_from_secret(:parity, secret, passphrase) when byte_size(secret) == 64 do
    secret = secret |> Base.decode16!(case: :upper) |> Eth.Encoding.to_hex()
    {:ok, _} = Ethereumex.HttpClient.request("parity_newAccountFromSecret", [secret, passphrase], [])
  end

  # private

  # returns well-funded faucet address for contract deployment or first address returned from node otherwise
  defp get_deployer_address(opts) do
    with {:ok, [addr | _]} <- Ethereumex.HttpClient.eth_accounts(),
         do: {:ok, from_hex(Keyword.get(opts, :faucet, addr))}
  end

  defp create_and_fund_authority_addr(opts) do
    with {:ok, authority} <- Ethereumex.HttpClient.request("personal_newAccount", [@passphrase], []),
         {:ok, _} <- fund_address_from_faucet(authority, opts) do
      {:ok, from_hex(authority)}
    end
  end

  defp get_exit_period(nil) do
    Application.fetch_env!(:omg_eth, :exit_period_seconds)
  end

  defp get_exit_period(exit_period), do: exit_period

  defp fund_address_from_faucet(account_enc, opts) do
    {:ok, [default_faucet | _]} = Ethereumex.HttpClient.eth_accounts()
    defaults = [faucet: default_faucet, initial_funds: @one_hundred_eth]

    %{faucet: faucet, initial_funds: initial_funds} =
      defaults
      |> Keyword.merge(opts)
      |> Enum.into(%{})

    unlock_if_possible(account_enc)

    params = %{from: faucet, to: account_enc, value: to_hex(initial_funds)}
    {:ok, tx_fund} = OMG.Eth.send_transaction(params)

    tx_fund |> WaitFor.eth_receipt(@about_4_blocks_time)
  end

  defp unlock_if_possible(account_enc) do
    unlock_if_possible(account_enc, OMG.Eth.backend())
  end

  defp unlock_if_possible(account_enc, :geth) do
    {:ok, true} = Ethereumex.HttpClient.request("personal_unlockAccount", [account_enc, @passphrase, 0], [])
  end

  defp unlock_if_possible(_account_enc, :parity) do
    :dont_bother_will_use_personal_sendTransaction
  end
end
