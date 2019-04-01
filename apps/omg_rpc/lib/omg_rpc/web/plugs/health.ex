defmodule OMG.RPC.Plugs.Health do
  @moduledoc """
  this is primarily a Plug, but we're subscribing to Alarms as well, so that we're able to reject API calls.
  """
  use GenServer
  require Logger

  @type t :: %__MODULE__{
          alarm_module: module(),
          raised: boolean()
        }
  defstruct alarm_module: nil, raised: true

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def handle_cast(:service_available, state) do
    {:noreply, %{state | raised: false}}
  end

  def handle_cast(:service_unavailable, state) do
    {:noreply, %{state | raised: true}}
  end

  def handle_event({:clear_alarm, {:ethereum_client_connection, _}}, state) do
    _ = Logger.warn(":ethereum_client_connection alarm was cleared. RPC service available.")
    :ok = GenServer.cast(__MODULE__, :service_available)
    {:ok, state}
  end

  def handle_event({:set_alarm, {:ethereum_client_connection, _}}, state) do
    _ = Logger.warn("Health check raised :ethereum_client_connection alarm. RPC Service unavailable.")
    :ok = GenServer.cast(__MODULE__, :service_unavailable)
    {:ok, state}
  end

  # flush
  def handle_event(event, state) do
    _ = Logger.info("Health got event: #{inspect(event)}. Ignoring.")
    {:ok, state}
  end

  def init([alarm_module]) do
    install()
    {:ok, %__MODULE__{alarm_module: alarm_module}}
  end

  ###
  ### PLUG
  ###
  def init(options), do: options

  def call(conn, _params) do
    conn
  end

  defp install do
    case Enum.member?(:gen_event.which_handlers(:alarm_handler), __MODULE__) do
      true -> :ok
      _ -> :alarm_handler.add_alarm_handler(__MODULE__)
    end
  end
end
