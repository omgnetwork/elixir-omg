defmodule OmiseGO.API.Eventer do

  alias Phoenix.PubSub
  alias OmiseGO.API.Notification
  alias OmiseGO.API.Notification.Spent
  alias OmiseGO.API.Notification.Received
  alias OmiseGO.API.Notification.BlockFinalized
  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.State.Transaction.Recovered

  @pubsub :eventer

  # TODO: put this module in proper place
  defmodule OmiseGO.Block do
    defstruct [:number, :hash]
  end

  ### Client

  def notify(event_triggers) do
    GenServer.cast(__MODULE__, {:notify, event_triggers})
  end

  def subscribe(topics) when is_list(topics) do
    subs = Enum.map(topics, &(PubSub.subscribe(@pubsub, &1)))
    subs
    |> Enum.reduce(:ok, fn (a, b) -> if b != :ok, do: :error, else: a end)
  end

  def unsubscribe(topics) when is_list(topics) do
    unsubs = Enum.map(topics, &(PubSub.unsubscribe(@pubsub, &1)))
    unsubs
    |> Enum.reduce(:ok, fn (a, b) -> if b != :ok, do: :error, else: a end)
  end

  ### Server

  use GenServer

  def init(:ok) do
    {:ok, nil}
  end

  def handle_cast({:notify, event_triggers}, state) do
    {notifications, _} = Core.notify(event_triggers)
    notifications
    |> Enum.each(fn [notification: n, topic: t] -> PubSub.broadcast(:eventer, t, n) end)
    {:noreply, state}
  end

  defmodule Core do

    @block_finalized_topic "block_finalized"
    @transaction_spent_topic_prefix "transactions/spent/"
    @transaction_received_topic_prefix "transactions/received/"

    @spec notify(any()) :: list([notification: Notification.t, topic: binary()])
    def notify(event_triggers) do
      Enum.flat_map(event_triggers, &(get_notification_with_topic(&1)))
    end

    defp get_notification_with_topic(%{tx: %Recovered{} = transaction}) do
      spender_notifications = get_spender_notifications(transaction)
      receiver_notifications = get_receiver_notifications(transaction)
      spender_notifications ++ receiver_notifications
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
      [notification: %Received{tx: transaction}, topic: @transaction_received_topic_prefix <> receiver]
    end

    defp get_notification_with_topic(%{block: %OmiseGO.Block{} = block}) do
      [
        [notification: %BlockFinalized{number: block.number, hash: block.hash},
         topic: @block_finalized_topic]
      ]
    end
  end
end
