defmodule OmiseGOWatcherWeb.Controller.JsonFallback do
  @moduledoc """
  Handle internal errors from with's used in json-returning endpoints, relying on external factors,
  e.g. Controller.Status depending on OmiseGO.Eth
  """

  use Phoenix.Controller

  def call(conn, {:error, reason}) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{:error => inspect(reason)})
  end
end
