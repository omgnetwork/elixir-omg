defmodule Itest.Poller do
  @moduledoc """
  Functions to poll the network for certain state changes.
  """

  require Logger

  alias Itest.ApiModel.SubmitTransactionResponse
  alias WatcherInfoAPI.Api.Account
  alias WatcherInfoAPI.Api.Transaction
  alias WatcherInfoAPI.Connection, as: WatcherInfo
  alias WatcherInfoAPI.Model.AddressBodySchema1

  @sleep_retry_sec 1_000
  @retry_count 30

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
  def get_balance(address), do: get_balance(address, @retry_count)

  @doc """
    API:: We know exactly what amount in WEI we want to recognize so we aggressively pull until...
  """
  def pull_balance_until_amount(address, amount), do: pull_balance_until_amount(address, amount, @retry_count)

  @doc """
    Ethereum:: pull Eth account balance until succeeds. We're solving connection issues with this.
  """
  def eth_get_balance(address), do: eth_get_balance(address, @retry_count)

  @doc """
    Ethereum:: Waits on the receipt status as 'confirmed'
  """
  def wait_on_receipt_confirmed(receipt_hash),
    do: wait_on_receipt_status(receipt_hash, "0x1", @retry_count)

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

      {:error, :closed} ->
        Process.sleep(@sleep_retry_sec)
        do_wait_on_receipt_status(receipt_hash, expected_status, counter - 1)

      {:error, :socket_closed_remotely} ->
        Process.sleep(@sleep_retry_sec)
        do_wait_on_receipt_status(receipt_hash, expected_status, counter - 1)

      {:ok, %{"status" => ^expected_status} = resp} ->
        revert_reason(resp)
        resp

      {:ok, resp} ->
        revert_reason(resp)
        %{"status" => ^expected_status} = resp
    end
  end

  defp get_transaction_receipt(receipt_hash),
    do: Ethereumex.HttpClient.eth_get_transaction_receipt(receipt_hash)

  defp get_balance(address, 0) do
    {:ok, response} = account_get_balance(address)
    Jason.decode!(response.body)["data"]
  end

  defp get_balance(address, counter) do
    response = account_get_balance(address)

    case response do
      {:ok, response} ->
        decoded_response = Jason.decode!(response.body)

        case decoded_response["data"] do
          [] ->
            Process.sleep(@sleep_retry_sec)
            get_balance(address, counter - 1)

          [data] ->
            data
        end

      _ ->
        # socket closed etc.
        Process.sleep(@sleep_retry_sec)
        get_balance(address, counter - 1)
    end
  end

  defp pull_balance_until_amount(address, _amount, 0) do
    {:ok, response} = account_get_balance(address)
    Jason.decode!(response.body)["data"]
  end

  defp pull_balance_until_amount(address, amount, counter) do
    response = account_get_balance(address)

    case response do
      {:ok, response} ->
        decoded_response = Jason.decode!(response.body)

        case decoded_response["data"] do
          # empty response is considered no account balance!
          [] when amount == 0 ->
            decoded_response["data"]

          [] ->
            Process.sleep(@sleep_retry_sec)
            pull_balance_until_amount(address, amount, counter - 1)

          [%{"amount" => ^amount} = data] ->
            data

          [_data] ->
            Process.sleep(@sleep_retry_sec)
            pull_balance_until_amount(address, amount, counter - 1)
        end

      _ ->
        # socket closed etc.
        Process.sleep(@sleep_retry_sec)
        pull_balance_until_amount(address, amount, counter - 1)
    end
  end

  defp eth_get_balance(address, 0) do
    {:ok, initial_balance} = eth_account_get_balance(address)
    {initial_balance, ""} = initial_balance |> String.replace_prefix("0x", "") |> Integer.parse(16)
    initial_balance
  end

  defp eth_get_balance(address, counter) do
    response = eth_account_get_balance(address)

    case response do
      {:ok, initial_balance} ->
        {initial_balance, ""} = initial_balance |> String.replace_prefix("0x", "") |> Integer.parse(16)
        initial_balance

      _ ->
        Process.sleep(@sleep_retry_sec)
        eth_get_balance(address, counter - 1)
    end
  end

  defp eth_account_get_balance(address) do
    Ethereumex.HttpClient.eth_get_balance(address)
  end

  defp account_get_balance(address) do
    Account.account_get_balance(
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

    _ =
      Logger.info(
        "Revert reason for #{inspect(response)}: revert string: #{inspect(reason)} revert string: #{
          inspect(Itest.Transactions.Encoding.to_binary(reason))
        }"
      )
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
end
