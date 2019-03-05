defmodule OMG.API.Alert.Alarm do
  @moduledoc """
  Interface for raising and clearing alarms.
  """
  alias OMG.API.Alert.AlarmHandler
  @behaviour AlarmHandler

  @impl AlarmHandler
  def geth_synchronisation_in_progress(node, reporter),
    do: {:geth_synchronisation_in_progress, %{node: node, reporter: reporter}}

  def raise(raw_alarm) do
    alarm = make_alarm(raw_alarm)
    do_raise(alarm)
  end

  defp do_raise(alarm) do
    case Enum.member?(all_raw(), alarm) do
      false ->
        :alarm_handler.set_alarm(alarm)

      _ ->
        :duplicate
    end
  end

  def clear(raw_alarm) do
    make_alarm(raw_alarm)
    |> :alarm_handler.clear_alarm()
  end

  def clear_all() do
    all_raw()
    |> Enum.each(&:alarm_handler.clear_alarm(&1))
  end

  def all() do
    all_raw()
    |> Enum.map(&format_alarm/1)
  end

  defp format_alarm({id, details}), do: %{id: id, details: details}
  defp format_alarm(alarm), do: %{id: alarm}

  defp all_raw(), do: :gen_event.call(:alarm_handler, AlarmHandler, :get_alarms)

  defp make_alarm({:geth_synchronisation_in_progress, node, reporter}) do
    geth_synchronisation_in_progress(node, reporter)
  end
end
