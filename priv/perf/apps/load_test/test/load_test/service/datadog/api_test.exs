defmodule LoadTest.Service.Datadog.APITest do
  use ExUnit.Case

  require FakeServer

  alias FakeServer.Response
  alias LoadTest.Service.Datadog.API

  @server_name :datadog
  @event %{
    "alert_type" => "error",
    "title" => "[Triggered] WatcherInfo.get_balances takes more than 40ms",
    "url" => "/event/event?id=5718361627942929581",
    "text" => "tag",
    "date_happened" => 1_605_191_364
  }

  setup do
    {:ok, server} = FakeServer.start(@server_name)
    {:ok, port} = FakeServer.port(@server_name)
    fakeserver_address = "http://localhost:" <> to_string(port) <> "/"

    datadog_params = Application.get_env(:load_test, :datadog)

    new_datadog_params = Keyword.put(datadog_params, :api_url, fakeserver_address)

    Application.put_env(:load_test, :datadog, new_datadog_params)

    FakeServer.put_route(@server_name, "/api/v1/events", Response.new(200, Jason.encode!(%{"events" => [@event]})))

    on_exit(fn ->
      FakeServer.stop(server)
      Application.put_env(:load_test, :datadog, datadog_params)
    end)

    :ok
  end

  describe "assert_metrics/3" do
    test "fetches events from datadog" do
      current_time = DateTime.utc_now()

      assert {:error, [event]} = API.assert_metrics("tag", current_time, current_time)

      assert @event["title"] == event["title"]
      assert "https://app.datadoghq.com" <> @event["url"] == event["url"]
    end
  end
end
