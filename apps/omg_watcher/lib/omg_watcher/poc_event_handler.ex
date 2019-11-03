defmodule OMG.Watcher.PocEventHandler do
  use GenServer
  alias OMG.Watcher.DB.EthEvent

  def start_link(subscribe_to) do
    GenServer.start_link(__MODULE__, subscribe_to, name: subscribe_to)
  end

  def init(subscribe_to) do
    :ok = OMG.Bus.subscribe(Atom.to_string(subscribe_to), link: true)
    {:ok, %{subscribe_to: subscribe_to}}
  end

  def handle_info(
        {:internal_event_bus, :sync_height, data},
        state
      ) do
    case state.subscribe_to do
      "exit_processor" -> EthEvent.insert_exits!(data)
      "depositor" -> EthEvent.insert_deposits!(data)
    end

    {:noreply, state}
  end
end
