defmodule OmiseGO.WS.HandlerTest do
  @moduledoc """
  Tests the process of exposing APIs via websocket using a test module ExampleAPI
  """
  use ExUnit.Case
  import OmiseGO.WS.Handler

  @timeout 100

  defmodule ExampleAPI do
    @moduledoc """
    Just an API-like module to expose
    """

    use OmiseGO.API.ExposeSpec
    @test_event_payload %{"test_event_payload" => "payload"}
    def test_event_payload, do: @test_event_payload

    @spec is_even_N(x :: integer) :: {:ok, boolean} | {:error, :badarg}
    def is_even_N(x) when x > 0 and is_integer(x), do: {:ok, rem(x, 2) == 0}
    def is_even_N(_), do: {:error, :badarg}

    @spec is_even_list(x :: [integer]) :: {:ok, boolean} | {:error, :badarg}
    def is_even_list(x) when is_list(x), do: {:ok, Enum.all?(x, fn x -> rem(x, 2) == 0 end)}
    def is_even_list(_), do: {:error, :badarg}

    @spec is_map_values_even(x :: %{:atom => integer}) :: {:ok, boolean} | {:error, :badarg}
    def is_map_values_even(x) when is_map(x) do
      checker = fn x -> rem(x, 2) == 0 end
      {:ok, Enum.all?(Map.values(x), checker)}
    end

    def is_map_values_even(_), do: {:error, :badarg}

    @spec event_me(subscriber :: pid) :: :ok
    def event_me(subscriber) do
      send(subscriber, {:event, @test_event_payload})
      :ok
    end
  end

  def call(x) do
    state = %{api: ExampleAPI}
    {:reply, {:text, rep}, nil, _} = websocket_handle({:text, x}, nil, state)
    {:ok, decoded} = Poison.decode(rep)
    decoded
  end

  def get_event(timeout \\ @timeout) do
    state = %{api: ExampleAPI}

    receive do
      msg ->
        {:reply, {:text, rep}, nil, _} = websocket_info(msg, nil, state)
        {:ok, decoded} = Poison.decode(rep)
        decoded
    after
      timeout -> throw(:timeouted)
    end
  end

  test "processes events" do
    assert %{"result" => "ok"} = call(~s({"method": "event_me", "params": {}, "type": "rq", "wsrpc": "1.0"}))
    assert get_event() == ExampleAPI.test_event_payload()
  end

  test "sane handler" do
    assert %{"result" => true} = call(~s({"method": "is_even_N", "params": {"x": 26}, "type": "rq", "wsrpc": "1.0"}))

    assert %{"result" => true} =
             call(~s({"method": "is_even_list", "params": {"x": [2, 4]}, "type": "rq", "wsrpc": "1.0"}))

    assert %{"result" => false} = call(~s({"method": "is_map_values_even", "params": {"x": {"a": 97, "b": 98}},
             "type": "rq", "wsrpc": "1.0"}))
    assert %{"result" => false} = call(~s({"method": "is_even_N", "params": {"x": 1}, "type": "rq", "wsrpc": "1.0"}))

    assert %{"error" => %{"code" => -32_603}} =
             call(~s({"method": "is_even_N", "params": {"x": -1}, "type": "rq", "wsrpc": "1.0"}))

    assert %{"error" => %{"code" => -32_601}} =
             call(~s({"method": ":lists.filtermap", "params": {"x": -1}, "type": "rq", "wsrpc": "1.0"}))
  end
end
