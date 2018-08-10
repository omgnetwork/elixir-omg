defmodule OmiseGOWatcher.TestHelper do
  @moduledoc """
  Module provides common testing functions used by App's tests.
  """

  import ExUnit.Assertions
  use Plug.Test

  def wait_for_process(pid, timeout \\ :infinity) when is_pid(pid) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, _, _} ->
        :ok
    after
      timeout ->
        throw({:timeouted_waiting_for, pid})
    end
  end

  def rest_call(method, path, params_or_body \\ nil, expected_resp_status \\ 200) do
    request = conn(method, path, params_or_body)
    response = request |> send_request
    assert response.status == expected_resp_status
    Poison.decode!(response.resp_body)
  end

  defp send_request(req) do
    req
    |> put_private(:plug_skip_csrf_protection, true)
    |> OmiseGOWatcherWeb.Endpoint.call([])
  end

  def create_topic(main_topic, subtopic), do: main_topic <> ":" <> subtopic
end
