defmodule Itest.Eventer do
  @moduledoc """
  Listens for events passed in as `listen_to`.
  """
  use WebSockex

  @subscription_id 1

  #
  # Client API
  #

  @doc """
  Starts a GenServer that listens to events.
  """
  @spec start_link(Keyword.t()) :: {:ok, pid()} | no_return()
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)

    case Process.whereis(name) do
      nil ->
        ws_url = Keyword.fetch!(opts, :ws_url)

        case WebSockex.start_link(ws_url, __MODULE__, opts, name: name) do
          {:error, {:already_started, pid}} ->
            {:ok, pid}

          {:ok, pid} ->
            spawn(fn -> listen(pid, opts) end)
            {:ok, pid}
        end

      pid ->
        {:ok, pid}
    end
  end

  # >> {"id": 1, "method": "eth_subscribe", "params": ["logs", {"address": "0x8320fe7702b96808f7bbc0d4a888ed1468216cfd", "topics": ["0xd78a0cb8bb633d06981248b816e7bd33c2a35a6089241d099fa519e361cab902"]}]}
  defp listen(pid, opts) do
    payload = %{
      jsonrpc: "2.0",
      id: @subscription_id,
      method: "eth_subscribe",
      params: [
        "logs",
        # %{"address" => Itest.Account.plasma_framework()}
        Keyword.fetch!(opts, :listen_to)
      ]
    }

    WebSockex.send_frame(pid, {:text, Jason.encode!(payload)})
  end

  #
  # Server API
  #

  @doc false
  @spec init(any()) :: {:ok, any()}
  def init(opts) do
    {:ok, opts}
  end

  # sobelow_skip ["DOS.StringToAtom"]
  @doc false
  @impl true
  def handle_frame({:text, msg}, state) do
    {:ok, decoded} = Jason.decode(msg)

    IO.inspect("got message on #{inspect(state)} msg -> ")
    IO.inspect(decoded)
    # listen_to = Keyword.fetch!(state, :listen_to)
    # event_bus = Keyword.fetch!(state, :event_bus)
    # :ok = apply(event_bus, :broadcast, [listen_to, {String.to_atom(listen_to), decoded}])
    {:ok, state}
  end
end
