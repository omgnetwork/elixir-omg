# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule Support.DevHelper do
  @moduledoc """
  Helpers used when setting up development environment and test fixtures, related to contracts and ethereum.
  Run against `geth --dev` and similar.
  """

  alias OMG.Eth
  alias OMG.Eth.Transaction
  alias Support.WaitFor
  import Eth.Encoding, only: [to_hex: 1, from_hex: 1, int_from_hex: 1]

  require Logger

  @one_hundred_eth trunc(:math.pow(10, 18) * 100)

  # about 4 Ethereum blocks on "realistic" networks, use to timeout synchronous operations in demos on testnets
  # NOTE: such timeout works only in dev setting; on mainnet one must track its transactions carefully
  @about_4_blocks_time 60_000

  @passphrase "ThisIsATestnetPassphrase"

  def create_conf_file(%{contract_addr: contract_addr, txhash_contract: txhash, authority_addr: authority_addr}) do
    contract_addr = Eth.RootChain.contract_map_to_hex(contract_addr)

    """
    use Mix.Config
    config :omg_eth,
      contract_addr: #{inspect(contract_addr)},
      txhash_contract: #{inspect(to_hex(txhash))},
      authority_addr: #{inspect(to_hex(authority_addr))}
    """
  end

  @doc """
  Will take a map with eth-account information (from &generate_entity/0) and then
  import priv key->unlock->fund with test ETH on that account

  Options:
    - :faucet - the address to send the test ETH from, assumed to be unlocked and have the necessary funds
    - :initial_funds_wei - the amount of test ETH that will be granted to every generated user
  """
  def import_unlock_fund(%{priv: account_priv}, opts \\ []) do
    {:ok, account_enc} = create_account_from_secret(backend(), account_priv, @passphrase)
    {:ok, _} = fund_address_from_faucet(account_enc, opts)

    {:ok, from_hex(account_enc)}
  end

  @doc """
  Use with contract-transacting functions that return {:ok, txhash}, e.g. `Eth.Token.mint`, for synchronous waiting
  for mining of a successful result
  """
  @spec transact_sync!({:ok, Eth.hash()}, keyword()) :: {:ok, map}
  def transact_sync!({:ok, txhash} = _transaction_submission_result, opts \\ []) when byte_size(txhash) == 32 do
    timeout = Keyword.get(opts, :timeout, @about_4_blocks_time)

    {:ok, _} =
      txhash
      |> WaitFor.eth_receipt(timeout)
      |> case do
        {:ok, %{"status" => "0x1"} = receipt} -> {:ok, receipt |> Map.update!("blockNumber", &int_from_hex(&1))}
        {:ok, %{"status" => "0x0"} = receipt} -> {:error, receipt |> Map.put("reason", get_reason(txhash))}
        other -> other
      end
  end

  # gets the `revert` reason for a failed transaction by txhash
  # based on https://gist.github.com/gluk64/fdea559472d957f1138ed93bcbc6f78a
  defp get_reason(txhash) do
    # we get the exact transaction details
    {:ok, tx} = Ethereumex.HttpClient.eth_get_transaction_by_hash(to_hex(txhash))
    # we use them (with minor tweak) to be called on the Ethereum client at the exact block of the original call
    {:ok, call_result} = tx |> Map.put("data", tx["input"]) |> Ethereumex.HttpClient.eth_call(tx["blockNumber"])
    # this call result is hex decoded and then additionally decoded with ABI, should yield a readable ascii-string
    if call_result == "0x", do: "out of gas, reason is 0x", else: call_result |> from_hex() |> abi_decode_reason()
  end

  defp abi_decode_reason(result) do
    bytes_to_throw_away = 2 * 32 + 4
    # trimming the 4-byte function selector, 32 byte size of size and 32 byte size
    result |> binary_part(bytes_to_throw_away, byte_size(result) - bytes_to_throw_away) |> String.trim(<<0>>)
  end

  @doc """
  Uses `transact_sync!` for synchronous deploy-transaction sending and extracts important data from the receipt
  """
  @spec deploy_sync!({:ok, Eth.hash()}) :: {:ok, Eth.hash(), Eth.address()}
  def deploy_sync!({:ok, txhash} = transaction_submission_result) do
    {:ok, %{"contractAddress" => contract, "status" => "0x1", "gasUsed" => _gas_used}} =
      transact_sync!(transaction_submission_result)

    {:ok, txhash, from_hex(contract)}
  end

  def wait_for_root_chain_block(awaited_eth_height, timeout \\ 600_000) do
    f = fn ->
      {:ok, eth_height} = Eth.get_ethereum_height()

      if eth_height < awaited_eth_height, do: :repeat, else: {:ok, eth_height}
    end

    WaitFor.ok(f, timeout)
  end

  def wait_for_next_child_block(blknum, timeout \\ 10_000, contract \\ nil) do
    f = fn ->
      {:ok, next_num} = Eth.RootChain.get_next_child_block(contract)

      if next_num < blknum, do: :repeat, else: {:ok, next_num}
    end

    WaitFor.ok(f, timeout)
  end

  def create_account_from_secret(:ganache, secret, passphrase),
    do: do_create_account_from_secret("personal_importRawKey", Eth.Encoding.to_hex(secret), passphrase)

  def create_account_from_secret(:geth, secret, passphrase),
    do: do_create_account_from_secret("personal_importRawKey", Base.encode16(secret), passphrase)

  def create_account_from_secret(:parity, secret, passphrase) when byte_size(secret) == 64,
    do: do_create_account_from_secret("parity_newAccountFromSecret", Eth.Encoding.to_hex(secret), passphrase)

  # private

  defp do_create_account_from_secret(method_name, secret, passphrase) do
    {:ok, _} = Ethereumex.HttpClient.request(method_name, [secret, passphrase], [])
  end

  defp fund_address_from_faucet(account_enc, opts) do
    {:ok, [default_faucet | _]} = Ethereumex.HttpClient.eth_accounts()
    defaults = [faucet: default_faucet, initial_funds_wei: @one_hundred_eth]

    %{faucet: faucet, initial_funds_wei: initial_funds_wei} =
      defaults
      |> Keyword.merge(opts)
      |> Enum.into(%{})

    unlock_if_possible(account_enc)

    params = %{from: faucet, to: account_enc, value: to_hex(initial_funds_wei)}

    {:ok, tx_fund} = Transaction.send(backend(), params)

    case Keyword.get(opts, :timeout) do
      nil -> WaitFor.eth_receipt(tx_fund, @about_4_blocks_time)
      timeout -> WaitFor.eth_receipt(tx_fund, timeout)
    end
  end

  defp unlock_if_possible(account_enc) do
    unlock_if_possible(account_enc, backend())
  end

  # ganache works the same as geth in this aspect
  defp unlock_if_possible(account_enc, :ganache), do: unlock_if_possible(account_enc, :geth)

  defp unlock_if_possible(account_enc, :geth) do
    {:ok, true} = Ethereumex.HttpClient.request("personal_unlockAccount", [account_enc, @passphrase, 0], [])
  end

  defp unlock_if_possible(_account_enc, :parity) do
    :dont_bother_will_use_personal_sendTransaction
  end

  defp backend() do
    Application.fetch_env!(:omg_eth, :eth_node)
  end
end
