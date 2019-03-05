defmodule OMG.Status.Alert.AlarmHandler do
  @moduledoc """
    This is the SASL alarm handler process.
  """

  def install() do
    previous_alarms = :alarm_handler.get_alarms()
    :ok = :gen_event.swap_handler(:alarm_handler, {:alarm_handler, :swap}, {__MODULE__, :ok})
    # migrates old alarms
    Enum.each(previous_alarms, &:alarm_handler.set_alarm(&1))
  end

  # -----------------------------------------------------------------
  # :gen_event handlers
  # -----------------------------------------------------------------
  def init(_args) do
    {:ok, %{alarms: []}}
  end

  def handle_call(:get_alarms, %{alarms: alarms} = state), do: {:ok, alarms, state}

  def handle_event({:set_alarm, new_alarm}, %{alarms: alarms} = state) do
    if Enum.any?(alarms, &(&1 == new_alarm)) do
      {:ok, state}
    else
      {:ok, %{alarms: [new_alarm | alarms]}}
    end
  end

  def handle_event({:clear_alarm, alarm_id}, %{alarms: alarms}) do
    new_alarms = Enum.filter(alarms, &(elem(&1, 0) != alarm_id))
    new_alarms = Enum.filter(new_alarms, &(&1 != alarm_id))
    {:ok, %{alarms: new_alarms}}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  def terminate(:swap, state), do: {__MODULE__, state}
  def terminate(_, _), do: :ok
end
