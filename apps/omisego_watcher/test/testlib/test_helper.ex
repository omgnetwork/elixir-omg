defmodule OmiseGOWatcher.TestHelper do
  @moduledoc """
  Module provides common testing functions used by App's tests.
  """

  use ExUnit.Case, async: true
  use Plug.Test

  def rest_call(method, path, params_or_body \\ nil) do
    request = conn(method, path, params_or_body)
    response = request |> send_request
    assert response.status == 200
    Poison.decode!(response.resp_body)
  end

  defp send_request(req) do
    req
    |> put_private(:plug_skip_csrf_protection, true)
    |> OmiseGOWatcherWeb.Endpoint.call([])
  end
end
