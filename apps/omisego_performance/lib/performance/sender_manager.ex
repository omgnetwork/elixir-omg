defmodule OmiseGO.Performance.SenderManager do
  @moduledoc """
  Registry-kind module to manage sender processes, helps to create and start senders and waits when all are done.
  """

  require Logger
  use GenServer

  @check_senders_done_every_ms 500

  @doc """
  Starts the sender's manager process
  """
  @spec start(ntx_to_send :: integer, nusers :: integer) :: pid
  def start(ntx_to_send, nusers) do
    {:ok, mypid} = GenServer.start_link(__MODULE__, {ntx_to_send, nusers}, name: __MODULE__)
    mypid
  end

  @doc """
  Starts sender processes and reschedule check whether they are done.
  """
  @spec init(tuple) :: map()
  def init({ntx_to_send, nusers}) do
    Logger.debug(fn -> "[SM] +++ init/1 called with #{nusers} users, each to send #{ntx_to_send} +++" end)

    senders = 1..nusers
            |> Enum.map(fn seqnum ->
                {:ok, pid} = OmiseGO.Performance.SenderServer.start_link({seqnum, ntx_to_send})
                {seqnum, pid}
            end)

    reschedule_check()
    {:ok, %{senders: senders, events: []}}
  end

  def sender_completed(seqnum) do
    GenServer.cast(__MODULE__, {:done, seqnum})
  end

  @doc """
  Checks whether registry has sender proceses registered
  """
  @spec handle_info(:check, state :: pid | atom)
  :: {:noreply, newstate :: pid | atom} | {:stop, :shutdown, state :: pid | atom}
  def handle_info(:check, %{senders: senders} = state) when length(senders) == 0 do
    Logger.debug(fn -> "[SM] +++ Stoping... +++" end)
    {:stop, :normal, state}
  end

  def handle_info(:check, state) do
    Logger.debug(fn -> "[SM]: Senders are alive" end)
    reschedule_check()
    {:noreply, state}
  end

  @doc """
  Removes sender process which has done sending from a registry.
  """
  @spec handle_cast({:done, seqnum :: integer}, state :: map()) :: {:noreply, map()}
  def handle_cast({:done, seqnum}, %{senders: senders} = state) do
    {:noreply, %{state | senders: Enum.reject(senders, &(match?({^seqnum, _}, &1)))}}
  end

  # Sends :check message to itself in @check_senders_done_every_ms milliseconds.
  # Message will be processed by module's :handle_info function.
  @spec reschedule_check() :: :ok
  defp reschedule_check, do: Process.send_after(self(), :check, @check_senders_done_every_ms)
end
