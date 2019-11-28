defmodule Itest.Poller do
  @moduledoc """
  Functions to poll the network for certain state changes.
  """

  require Logger

  @sleep_retry_sec 5_000

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
    {:ok, receipt} = response = get_transaction_receipt(receipt_hash)

    unless receipt && receipt["status"] == status do
      Process.sleep(@sleep_retry_sec)
      do_wait_on_receipt_status(receipt_hash, status, counter - 1)
    end

    response
  end

  defp get_transaction_receipt(receipt_hash),
    do: Ethereumex.HttpClient.eth_get_transaction_receipt(receipt_hash)
end
