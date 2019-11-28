defmodule Itest.Poller do
  @moduledoc """
  Functions to poll the network for certain state changes.
  """

  require Logger

  alias Itest.ApiModel.SubmitTransactionResponse
  alias WatchersInformationalAPI.Api.Account
  alias WatchersInformationalAPI.Api.Transaction
  alias WatchersInformationalAPI.Connection, as: WatcherInformational

  @sleep_retry_sec 5_000
  @retry_count 60

  def submit_typed(typed_data_signed), do: submit_typed(typed_data_signed, @retry_count)
  def get_balance(address), do: get_balance(address, @retry_count)
  # amount in WEI!
  def pull_balance_until_amount(address, amount), do: pull_balance_until_amount(address, amount, @retry_count)
  def eth_get_balance(address), do: eth_get_balance(address, @retry_count)

  @doc """
  Waits on the receipt status as 'confirmed'
  """
  def wait_on_receipt_confirmed(receipt_hash, counter),
    do: wait_on_receipt_status(receipt_hash, "0x1", counter)

  defp wait_on_receipt_status(receipt_hash, _status, 0), do: get_transaction_receipt(receipt_hash)

  defp wait_on_receipt_status(receipt_hash, status, counter) do
    _ = Logger.info("Waiting on #{receipt_hash} for status #{status} for #{counter} seconds")
    do_wait_on_receipt_status(receipt_hash, status, counter)
  end

  defp do_wait_on_receipt_status(receipt_hash, status, counter) do
    response = get_transaction_receipt(receipt_hash)
    # response might break with {:error, :closed} or {:error, :socket_closed_remotely}

    case response do
      {:ok, receipt} ->
        unless receipt && receipt["status"] == status do
          Process.sleep(@sleep_retry_sec)
          do_wait_on_receipt_status(receipt_hash, status, counter - 1)
        end

        response

      _ ->
        Process.sleep(@sleep_retry_sec)
        do_wait_on_receipt_status(receipt_hash, status, counter - 1)
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

          [data] ->
            case data["amount"] do
              ^amount ->
                data

              _ ->
                Process.sleep(@sleep_retry_sec)
                pull_balance_until_amount(address, amount, counter - 1)
            end
        end

      _ ->
        # socket closed etc.
        Process.sleep(@sleep_retry_sec)
        pull_balance_until_amount(address, amount, counter - 1)
    end
  end

  defp account_get_balance(address) do
    Account.account_get_balance(
      WatcherInformational.new(),
      %{
        address: address
      }
    )
  end

  defp eth_get_balance(address, 0) do
    {:ok, response} = account_get_balance(address)
    Jason.decode!(response.body)["data"]
  end

  defp eth_get_balance(address, counter) do
    response = eth_account_get_balance(address)

    case response do
      {:ok, _} ->
        response

      _ ->
        Process.sleep(@sleep_retry_sec)
        eth_get_balance(address, counter - 1)
    end
  end

  defp eth_account_get_balance(address) do
    Ethereumex.HttpClient.eth_get_balance(address)
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
        struct(SubmitTransactionResponse, decoded_response)
    end
  end

  defp execute_submit_typed(typed_data_signed) do
    Transaction.submit_typed(WatcherInformational.new(), typed_data_signed)
  end
end
