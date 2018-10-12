# Copyright 2018 OmiseGO Pte Ltd
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

  import Eth.Encoding

  require Logger

  @one_hundred_eth trunc(:math.pow(10, 18) * 100)

  # about 4 Ethereum blocks on "realistic" networks, use to timeout synchronous operations in demos on testnets
  # NOTE: such timeout works only in dev setting; on mainnet one must track its transactions carefully
  @about_4_blocks_time 60_000

  @doc """
  Prepares the developer's environment with respect to the root chain contract and its configuration within
  the application.

   - `root_path` should point to `elixir-omg` root or wherever where `./contracts/build` holds the compiled contracts
  """
  def prepare_env!(root_path \\ "./") do
    with {:ok, _} <- Application.ensure_all_started(:ethereumex),
         {:ok, authority} <- create_and_fund_authority_addr(),
         {:ok, txhash, contract_addr} <- Eth.RootChain.create_new(root_path, authority) do
      %{contract_addr: contract_addr, txhash_contract: txhash, authority_addr: authority}
    else
      {:error, :econnrefused} = error ->
        Logger.error(fn -> "It seems that Ethereum instance is not running. Check README.md" end)
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

  def create_and_fund_authority_addr do
    with {:ok, authority} <- Ethereumex.HttpClient.request("personal_newAccount", [""], []),
         {:ok, _} <- unlock_fund(authority) do
      {:ok, from_hex(authority)}
    end
  end

  @doc """
  Will take a map with eth-account information (from &generate_entity/0) and then
  import priv key->unlock->fund with lots of ether on that account
  """
  def import_unlock_fund(%{priv: account_priv}) do
    account_priv_enc = Base.encode16(account_priv)

    {:ok, account_enc} = Ethereumex.HttpClient.request("personal_importRawKey", [account_priv_enc, ""], [])
    {:ok, _} = unlock_fund(account_enc)

    {:ok, from_hex(account_enc)}
  end

  def make_deposits(value, accounts, contract \\ nil) do
    deposit = fn account ->
      {:ok, receipt} = OMG.Eth.RootChain.deposit(value, account.addr, contract) |> transact_sync!()
      deposit_blknum = OMG.Eth.RootChain.deposit_blknum_from_receipt(receipt)

      {:ok, account, deposit_blknum, value}
    end

    accounts
    |> Enum.map(&Task.async(fn -> deposit.(&1) end))
    |> Enum.map(fn task -> Task.await(task, :infinity) end)
  end

  @doc """
  Use with contract-transacting functions that return {:ok, txhash}, e.g. `Eth.Token.mint`, for synchronous waiting
  for mining of a successful result
  """
  def transact_sync!({:ok, txhash} = _transaction_submission_result) do
    {:ok, %{"status" => "0x1"}} = WaitFor.eth_receipt(txhash, @about_4_blocks_time)
  end

  # private

  defp unlock_fund(account_enc) do
    {:ok, true} = Ethereumex.HttpClient.request("personal_unlockAccount", [account_enc, "", 0], [])

    {:ok, [eth_source_address | _]} = Ethereumex.HttpClient.eth_accounts()

    {:ok, tx_fund} =
      %{from: eth_source_address, to: account_enc, value: to_hex(@one_hundred_eth)}
      |> Ethereumex.HttpClient.eth_send_transaction()

    tx_fund |> from_hex() |> WaitFor.eth_receipt()
  end
end
