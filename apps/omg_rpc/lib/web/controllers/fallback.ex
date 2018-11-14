defmodule OMG.RPC.Web.Controller.Fallback do
  use Phoenix.Controller

  def call(conn, :error), do: call(conn, {:error, :unknown_error})

  def call(conn, {:error, reason}) do
    json(conn, %{
      version: "1",
      success: false,
      data: %{
        object: :error,
        code: "#{action_name(conn)}:#{inspect(reason)}",
        description: nil
      }
    })
  end
end
