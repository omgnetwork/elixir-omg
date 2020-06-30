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

defmodule Itest.Poller do
  @moduledoc """
  Functions to poll the network for certain state changes.
  """

  require Logger

  alias Itest.ApiModel.SubmitTransactionResponse
  alias Itest.Transactions.Currency
  alias Itest.Transactions.Encoding
  alias WatcherInfoAPI.Api.Transaction
  alias WatcherInfoAPI.Connection, as: WatcherInfo
  alias WatcherInfoAPI.Model.AddressBodySchema1
  alias WatcherSecurityCriticalAPI.Api.Status

  @sleep_retry_sec 1_000
  @retry_count 400

  def pull_for_utxo_until_recognized_deposit(account, amount, currency, blknum) do
    payload = %AddressBodySchema1{address: account}
    pull_for_utxo_until_recognized_deposit(payload, amount, currency, blknum, @retry_count)
  end

  def pull_api_until_successful(module, function, connection, payload \\ nil),
    do: pull_api_until_successful(module, function, connection, payload, @retry_count)

  @doc """
  API:: If we're trying to transact with UTXOs that were not recognized *yet*
  """
  def submit_typed(typed_data_signed), do: submit_typed(typed_data_signed, @retry_count)

  @doc """
  API:: We pull account balance until we recongnize a change from 0 (which is []) to something
  """
  def get_balance(address, currency \\ Currency.ether()) do
    get_balance(address, Encoding.to_hex(currency), @retry_count)
  end

  @doc """
  API:: We know exactly what amount in WEI we want to recognize so we aggressively pull until...
  """
  def pull_balance_until_amount(address, amount, currency \\ Currency.ether()) do
    pull_balance_until_amount(address, amount, Encoding.to_hex(currency), @retry_count)
  end

  @doc """
  Ethereum:: pull root chain account balance until succeeds. We're solving connection issues with this.
  """
  def root_chain_get_balance(address, currency \\ Currency.ether()) do
    ether = Currency.ether()

    case currency do
      ^ether ->
        root_chain_get_eth_balance(address, @retry_count)

      _ ->
        root_chain_get_erc20_balance(address, currency, @retry_count)
    end
  end

  @doc """
  Checks status until the list of the byzantine events (by name, regardless of order) matches to `expected_events`
  """
  def all_events_in_status?(expected_events), do: all_events_in_status?(expected_events, @retry_count)

  @doc """
  Ethereum:: Waits on the receipt status as 'confirmed'
  """
  def wait_on_receipt_confirmed(receipt_hash),
    do: wait_on_receipt_status(receipt_hash, "0x1", @retry_count)

  @doc """
  API:: Pull until the utxo is not found for the address.
  """
  def utxo_absent?(address, utxo_pos), do: utxo_absent?(address, utxo_pos, @retry_count)

  @doc """
  API:: Pull until the exitable utxo is not found for the address.
  """
  def exitable_utxo_absent?(address, utxo_pos), do: exitable_utxo_absent?(address, utxo_pos, @retry_count)

  #######################################################################################################
  ### PRIVATE
  #######################################################################################################
  defp pull_api_until_successful(module, function, connection, payload, 0),
    do: Jason.decode!(apply(module, function, [connection, payload]))["data"]

  defp pull_api_until_successful(module, function, connection, payload, counter) do
    response =
      case payload do
        nil -> apply(module, function, [connection])
        _ -> apply(module, function, [connection, payload])
      end

    case response do
      {:ok, data} ->
        case Jason.decode!(data.body) do
          %{"success" => true} = resp ->
            resp["data"]

          _ ->
            Process.sleep(@sleep_retry_sec)
            pull_api_until_successful(module, function, connection, payload, counter - 1)
        end

      _ ->
        Process.sleep(@sleep_retry_sec)
        pull_api_until_successful(module, function, connection, payload, counter - 1)
    end
  end

  defp wait_on_receipt_status(receipt_hash, _status, 0), do: get_transaction_receipt(receipt_hash)

  defp wait_on_receipt_status(receipt_hash, status, counter) do
    _ = Logger.info("Waiting on #{receipt_hash} for status #{status} for #{counter} seconds")
    do_wait_on_receipt_status(receipt_hash, status, counter)
  end

  defp do_wait_on_receipt_status(receipt_hash, expected_status, counter) do
    response = get_transaction_receipt(receipt_hash)
    # response might break with {:error, :closed} or {:error, :socket_closed_remotely}
    case response do
      {:ok, nil} ->
        Process.sleep(@sleep_retry_sec)
        do_wait_on_receipt_status(receipt_hash, expected_status, counter - 1)

      {:error, _} ->
        Process.sleep(@sleep_retry_sec)
        do_wait_on_receipt_status(receipt_hash, expected_status, counter - 1)

      {:ok, %{"status" => ^expected_status} = resp} ->
        revert_reason(resp)
        resp

      {:ok, resp} ->
        revert_reason(resp)
        resp
    end
  end

  defp get_transaction_receipt(receipt_hash),
    do: Ethereumex.HttpClient.eth_get_transaction_receipt(receipt_hash)

  defp get_balance(address, currency, 0) do
    {:ok, response} = account_get_balances(address)
    Jason.decode!(response.body)["data"]
    # raise "Could not get the account balance for token address #{currency}. Got: #{inspect(data)}"
  end

  defp get_balance(address, currency, counter) do
    response =
      case account_get_balances(address) do
        {:ok, response} ->
          decoded_response = Jason.decode!(response.body)
          Enum.find(decoded_response["data"], :error, fn data -> data["currency"] == currency end)

        _ ->
          :error
      end

    case response do
      :error ->
        Process.sleep(@sleep_retry_sec)
        get_balance(address, currency, counter - 1)

      balance ->
        balance
    end
  end

  defp pull_balance_until_amount(address, amount, currency, 0) do
    {:ok, response} = account_get_balances(address)
    data = Jason.decode!(response.body)["data"]
    raise "Could not get the account balance of #{amount} for token address #{currency}. Got: #{inspect(data)}"
  end

  defp pull_balance_until_amount(address, amount, currency, counter) do
    response =
      case account_get_balances(address) do
        {:ok, response} ->
          decoded_response = Jason.decode!(response.body)
          Enum.find(decoded_response["data"], fn data -> data["currency"] == currency end)

        _ ->
          # socket closed etc.
          :error
      end

    case response do
      # empty response is considered no account balance!
      nil when amount == 0 ->
        nil

      %{"amount" => ^amount} = balance ->
        balance

      _ ->
        Process.sleep(@sleep_retry_sec)
        pull_balance_until_amount(address, amount, currency, counter - 1)
    end
  end

  defp root_chain_get_eth_balance(address, 0) do
    {:ok, initial_balance} = eth_account_get_balance(address)
    {initial_balance, ""} = initial_balance |> String.replace_prefix("0x", "") |> Integer.parse(16)
    initial_balance
  end

  defp root_chain_get_eth_balance(address, counter) do
    response = eth_account_get_balance(address)

    case response do
      {:ok, initial_balance} ->
        {initial_balance, ""} = initial_balance |> String.replace_prefix("0x", "") |> Integer.parse(16)
        initial_balance

      _ ->
        Process.sleep(@sleep_retry_sec)
        root_chain_get_eth_balance(address, counter - 1)
    end
  end

  defp eth_account_get_balance(address) do
    Ethereumex.HttpClient.eth_get_balance(address)
  end

  defp root_chain_get_erc20_balance(address, currency, 0) do
    do_root_chain_get_erc20_balance(address, currency)
  end

  defp root_chain_get_erc20_balance(address, currency, counter) do
    case do_root_chain_get_erc20_balance(address, currency) do
      {:ok, balance} ->
        balance

      _ ->
        Process.sleep(@sleep_retry_sec)
        root_chain_get_erc20_balance(address, currency, counter - 1)
    end
  end

  defp do_root_chain_get_erc20_balance(address, currency) do
    data = ABI.encode("balanceOf(address)", [Encoding.to_binary(address)])

    case Ethereumex.HttpClient.eth_call(%{to: Encoding.to_hex(currency), data: Encoding.to_hex(data)}) do
      {:ok, result} ->
        balance =
          result
          |> Encoding.to_binary()
          |> ABI.TypeDecoder.decode([{:uint, 256}])
          |> hd()

        {:ok, balance}

      error ->
        error
    end
  end

  defp account_get_balances(address) do
    WatcherInfoAPI.Api.Account.account_get_balance(
      WatcherInfo.new(),
      %{
        address: address
      }
    )
  end

  defp submit_typed(typed_data_signed, 0), do: execute_submit_typed(typed_data_signed)

  defp submit_typed(typed_data_signed, counter) do
    {:ok, response} = execute_submit_typed(typed_data_signed)
    decoded_response = Jason.decode!(response.body)["data"]

    case decoded_response do
      %{"messages" => %{"code" => "submit:utxo_not_found"}} ->
        Process.sleep(@sleep_retry_sec)
        submit_typed(typed_data_signed, counter - 1)

      %{"messages" => %{"code" => "operation:service_unavailable"}} ->
        Process.sleep(@sleep_retry_sec)
        submit_typed(typed_data_signed, counter - 1)

      %{"txhash" => _} ->
        SubmitTransactionResponse.to_struct(decoded_response)
    end
  end

  defp execute_submit_typed(typed_data_signed) do
    Transaction.submit_typed(WatcherInfo.new(), typed_data_signed)
  end

  defp revert_reason(%{"status" => "0x1"}), do: :ok

  defp revert_reason(%{"status" => "0x0"} = response) do
    {:ok, tx} = Ethereumex.HttpClient.eth_get_transaction_by_hash(response["transactionHash"])

    {:ok, reason} = Ethereumex.HttpClient.eth_call(Map.put(tx, "data", tx["input"]), tx["blockNumber"])
    hash = response["transactionHash"]

    _ =
      Logger.info(
        "Revert reason for #{inspect(hash)}: revert string: #{inspect(decode_reason(reason))}, revert binary: #{
          inspect(Itest.Transactions.Encoding.to_binary(reason), limit: :infinity)
        }"
      )
  end

  defp decode_reason(reason) do
    # https://ethereum.stackexchange.com/questions/48383/how-to-receive-revert-reason-for-past-transactions
    reason |> String.split_at(138) |> elem(1) |> Base.decode16!(case: :lower) |> String.chunk(:printable)
  end

  defp pull_for_utxo_until_recognized_deposit(payload, _, _, _, 0) do
    {:ok, data} = WatcherInfoAPI.Api.Account.account_get_utxos(WatcherInfo.new(), payload)
    Jason.decode!(data.body)
  end

  defp pull_for_utxo_until_recognized_deposit(payload, amount, currency, blknum, counter) do
    response = WatcherInfoAPI.Api.Account.account_get_utxos(WatcherInfo.new(), payload)

    case response do
      {:ok, data} ->
        find_deposit(Jason.decode!(data.body), payload, {amount, currency, blknum}, counter)

      _ ->
        Process.sleep(@sleep_retry_sec)
        pull_for_utxo_until_recognized_deposit(payload, amount, currency, blknum, counter)
    end
  end

  defp find_deposit(%{"success" => true, "data" => utxos} = data, payload, {amount, currency, blknum}, counter) do
    has_deposit =
      Enum.find(utxos, fn
        # does the UTXO set contain our deposit?
        %{"amount" => ^amount, "blknum" => ^blknum, "currency" => ^currency} ->
          true

        _ ->
          false
      end)

    case is_map(has_deposit) do
      true ->
        data

      _ ->
        Process.sleep(@sleep_retry_sec)
        pull_for_utxo_until_recognized_deposit(payload, amount, currency, blknum, counter - 1)
    end
  end

  defp find_deposit(_, payload, {amount, currency, blknum}, counter) do
    Process.sleep(@sleep_retry_sec)
    pull_for_utxo_until_recognized_deposit(payload, amount, currency, blknum, counter - 1)
  end

  defp all_events_in_status?(expected, 0) do
    _ = Logger.warn("Byzantine events stuck on: #{inspect(get_byzantine_events())}, expecting: #{inspect(expected)}")
    false
  end

  defp all_events_in_status?(expected_events, counter) do
    byzantine_events = get_byzantine_events()

    if Enum.sort(byzantine_events) == Enum.sort(expected_events) do
      true
    else
      Process.sleep(@sleep_retry_sec)
      all_events_in_status?(expected_events, counter - 1)
    end
  end

  defp get_byzantine_events() do
    pull_api_until_successful(Status, :status_get, WatcherSecurityCriticalAPI.Connection.new())
    |> Map.fetch!("byzantine_events")
    |> Enum.map(& &1["event"])
  end

  defp utxo_absent?(address, utxo_pos, 0) do
    params = %AddressBodySchema1{address: address}
    {:ok, response} = WatcherInfoAPI.Api.Account.account_get_utxos(WatcherInfo.new(), params)
    utxos = Jason.decode!(response.body)["data"]

    _ = Logger.warn("UTXO #{inspect(utxo_pos)} should be absent. Found in: #{inspect(utxos)}")

    false
  end

  defp utxo_absent?(address, utxo_pos, counter) do
    params = %AddressBodySchema1{address: address}
    {:ok, response} = WatcherInfoAPI.Api.Account.account_get_utxos(WatcherInfo.new(), params)
    utxos = Jason.decode!(response.body)["data"]

    if Enum.any?(utxos, fn utxo -> utxo["utxo_pos"] == utxo_pos end) do
      true
    else
      Process.sleep(@sleep_retry_sec)
      utxo_absent?(address, utxo_pos, counter - 1)
    end
  end

  defp exitable_utxo_absent?(address, utxo_pos, 0) do
    params = %AddressBodySchema1{address: address}
    {:ok, response} = WatcherSecurityCriticalAPI.Api.Account.account_get_exitable_utxos(WatcherInfo.new(), params)
    utxos = Jason.decode!(response.body)["data"]

    _ = Logger.warn("UTXO #{inspect(utxo_pos)} should be absent from exitable utxos. Found in #{inspect(utxos)}")

    false
  end

  defp exitable_utxo_absent?(address, utxo_pos, counter) do
    params = %AddressBodySchema1{address: address}
    {:ok, response} = WatcherSecurityCriticalAPI.Api.Account.account_get_exitable_utxos(WatcherInfo.new(), params)
    utxos = Jason.decode!(response.body)["data"]

    if Enum.any?(utxos, fn utxo -> utxo["utxo_pos"] == utxo_pos end) do
      true
    else
      Process.sleep(@sleep_retry_sec)
      exitable_utxo_absent?(address, utxo_pos, counter - 1)
    end
  end
end
