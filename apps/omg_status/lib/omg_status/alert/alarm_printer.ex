defmodule OMG.Status.AlarmPrinter do
  @moduledoc """
    A loud reminder of raised events
  """
  use GenServer
  alias OMG.Status.Alert.Alarm
  require Logger
  @interval 5_000
  # 5 minutes
  @max_interval 300_000
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    _ = :timer.send_after(@interval, :print_alarms)
    {:ok, %{previous_backoff: @interval}}
  end

  def handle_info(:print_alarms, state) do
    :ok = Enum.each(Alarm.all(), fn alarm -> Logger.warn("An alarm was raised #{inspect(alarm)}") end)

    previous_backoff =
      case @max_interval < state.previous_backoff do
        true ->
          @interval

        false ->
          state.previous_backoff
      end

    next_backoff = round(previous_backoff * 2) + Enum.random(-1000..1000)
    _ = :timer.send_after(next_backoff, :print_alarms)
    {:noreply, %{previous_backoff: next_backoff}}
  end
end
