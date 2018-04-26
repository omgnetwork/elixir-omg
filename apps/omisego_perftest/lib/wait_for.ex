defmodule OmiseGO.PerfTest.WaitFor do
  @moduledoc """
  Checks whether registry has sender proceses registered
  """

  require Logger
  use GenServer

  @check_registry_every_ms 250

  @doc """
  Starts the registry checker process
  """
  def start(registry) do
    {:ok, mypid} = GenServer.start_link(__MODULE__, registry)
    mypid
  end

  def init(args) do
    Logger.debug "[WF] +++ init/1 called with args: '#{args}' +++"
    reschedule_check()
    {:ok, args}
  end

  @doc """
  Checks whether registry has sender proceses registered
  """
  @spec handle_info(:check, state :: pid | atom) :: {:noreply, newstate :: pid | atom} | {:stop, :shutdown, state :: pid | atom}
  def handle_info(:check, registry) do
    senders = Registry.lookup(registry, :sender)

    unless Enum.empty?(senders) do
      Logger.debug "[WF]: Senders are alive"
      reschedule_check()
      {:noreply, registry}
    else
      Logger.debug "[WF] +++ Stoping... +++"
      {:stop, :normal, registry}
    end
  end

  defp reschedule_check(), do: Process.send_after(self(), :check, @check_registry_every_ms)
end
