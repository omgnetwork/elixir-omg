defmodule OMG.Status.Alert.Alarm do
  @moduledoc """
  Interface for raising and clearing alarms.
  """
  alias OMG.Status.Alert.AlarmHandler

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
end
