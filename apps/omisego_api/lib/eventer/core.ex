defmodule OmiseGO.API.Eventer.Core do
  @moduledoc """
  Functional core of eventer
  """

  alias OmiseGO.API.Notification
  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.Block

  @block_finalized_topic "block_finalized"
  @transaction_spent_topic_prefix "transactions/spent/"
  @transaction_received_topic_prefix "transactions/received/"

  @spec notify(any()) :: list({Notification.t, binary()})
  def notify(event_triggers) do
    Enum.flat_map(event_triggers, &(get_notification_with_topic(&1)))
  end

  defp get_notification_with_topic(%{tx: %Transaction.Recovered{} = transaction}) do
    spender_notifications = get_spender_notifications(transaction)
    receiver_notifications = get_receiver_notifications(transaction)
    spender_notifications ++ receiver_notifications
  end
  defp get_notification_with_topic(%{block: %Block{} = block}) do
    [
      {%Notification.BlockFinalized{number: block.number, hash: block.hash}, @block_finalized_topic}
    ]
  end

  defp get_spender_notifications(
    %Transaction.Recovered{raw_tx: _raw_tx, signed_tx_hash: _signed_tx_hash,
                           spender1: spender1, spender2: spender2} = recovered_tx) do

    [spender1, spender2]
    |> Enum.filter(&Transaction.account_address?/1)
    |> Enum.map(&(create_spender_notification(recovered_tx, &1)))
    |> Enum.uniq
  end

  defp create_spender_notification(%Transaction.Recovered{} = transaction, spender) do
    {%Notification.Spent{tx: transaction}, @transaction_spent_topic_prefix <> spender}
  end

  defp get_receiver_notifications(%Transaction.Recovered{raw_tx: raw_tx, signed_tx_hash: _signed_tx_hash,
                                                         spender1: _spender1, spender2: _spender2} = recovered_tx) do
    [raw_tx.newowner1, raw_tx.newowner2]
    |> Enum.filter(&Transaction.account_address?/1)
    |> Enum.map(&(create_receiver_notification(recovered_tx, &1)))
    |> Enum.uniq
  end

  defp create_receiver_notification(%Transaction.Recovered{} = transaction, receiver) do
    {%Notification.Received{tx: transaction}, @transaction_received_topic_prefix <> receiver}
  end
end
