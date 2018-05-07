defmodule OmiseGO.WS.Server do
  @moduledoc """
  Cowboy server serving the Websocket handler
  """

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start, [nil, nil]}
    }
  end

  def start(_type, _args) do
    ws_port = Application.get_env(:omisego_ws, :omisego_api_ws_port)
    dispatch_config = build_dispatch_config()
    {:ok, _} = :cowboy.start_http(:http, 100, [{:port, ws_port}], [{:env, [{:dispatch, dispatch_config}]}])
  end

  defp build_dispatch_config do
    :cowboy_router.compile([{:_, [{"/", OmiseGO.WS.Handler, []}]}])
  end
end
