defmodule OmiseGO.WS.Application.Test do
  @moduledoc """
  Test the supervision tree stuff of the app
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false

  def recv!(websocket) do
    {:text, response} = Socket.Web.recv!(websocket)

    case Poison.decode!(response) do
      %{"result" => decoded_result, "type" => "rs", "wsrpc" => "1.0"} -> {:ok, decoded_result}
      %{"source" => source} = event when is_binary(source) -> event
      %{"error" => decoded_error, "type" => "rs", "wsrpc" => "1.0"} -> {:error, decoded_error}
    end
  end

  def send!(websocket, method, params) when is_atom(method) and is_map(params) do
    encoded_message = Poison.encode!(%{wsrpc: "1.0", type: :rq, method: method, params: params})

    websocket
    |> Socket.Web.send!({
      :text,
      encoded_message
    })
  end

  def sendrecv!(websocket, method, params) when is_atom(method) and is_map(params) do
    :ok = send!(websocket, method, params)
    recv!(websocket)
  end

  test "OmiseGO Websockets should start fine" do
    assert {:ok, started} = Application.ensure_all_started(:omisego_ws)
    assert :omisego_ws in (Application.started_applications() |> Enum.map(fn {atom, _, _} -> atom end))
    for app <- started, do: :ok = Application.stop(app)
  end

  test "connection " do
    assert {:ok, _} = Application.ensure_all_started(:omisego_ws)
    assert {:ok, _} = Socket.Web.connect("localhost", Application.get_env(:omisego_ws, :omisego_api_ws_port))
  end
end
