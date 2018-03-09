defmodule OmiseGO.API.Eventer.Core do

  alias OmiseGO.API.Notification
  alias OmiseGO.API.Notification.Spent
  alias OmiseGO.API.Notification.Received
  alias OmiseGO.API.Notification.BlockFinalized
  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.State.Transaction.Recovered

  @block_finalized_topic "block_finalized"
  @transaction_spent_topic_prefix "transactions/spent/"
  @transaction_received_topic_prefix "transactions/received/"

  # TODO: put this module in proper place
  defmodule OmiseGO.Block do
    defstruct [:number, :hash]
  end

  @spec notify(any()) :: list({Notification.t, binary()})
  def notify(event_triggers) do
    Enum.flat_map(event_triggers, &(get_notification_with_topic(&1)))
  end

  defp get_notification_with_topic(%{tx: %Recovered{} = transaction}) do
    spender_notifications = get_spender_notifications(transaction)
    receiver_notifications = get_receiver_notifications(transaction)
    spender_notifications ++ receiver_notifications
  end
  defp get_notification_with_topic(%{block: %OmiseGO.Block{} = block}) do
    [
      {%BlockFinalized{number: block.number, hash: block.hash}, @block_finalized_topic}
    ]
  end

  defp get_spender_notifications(%Recovered{raw_tx: transaction, spender1: spender1, spender2: spender2}) do
    [spender1, spender2]
    |> Enum.filter(&Transaction.account_address?/1)
    |> Enum.map(&(create_spender_notification(transaction, &1)))
    |> Enum.uniq
  end

  defp create_spender_notification(transaction, spender) do
    [notification: %Spent{tx: transaction}, topic: @transaction_spent_topic_prefix <> spender]
  end

  defp get_receiver_notifications(%Recovered{raw_tx: transaction}) do
    [transaction.newowner1, transaction.newowner2]
    |> Enum.filter(&Transaction.account_address?/1)
    |> Enum.map(&(create_receiver_notification(transaction, &1)))
    |> Enum.uniq
  end

  defp create_receiver_notification(transaction, receiver) do
    {%Received{tx: transaction}, @transaction_received_topic_prefix <> receiver}
  end
end
