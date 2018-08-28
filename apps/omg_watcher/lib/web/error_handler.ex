defmodule OMG.Watcher.Web.ErrorHandler do
  @moduledoc """
  Handles API errors by mapping the error to its response code and description.
  """
  alias OMG.Watcher.Web.Serializer

  import Plug.Conn, only: [halt: 1]
  import Phoenix.Controller, only: [json: 2]

  @errors %{
    invalid_challenge_of_exit: %{
      code: "challenge:invalid",
      description: "The challenge of particular exit is invalid"
    },
    transaction_not_found: %{
      code: "transaction:not_found",
      description: "The transacion doesn't exists"
    }
  }

  @doc """
  Handles response with custom error code and description.
  """
  @spec handle_error(Plug.Conn.t(), atom() | String.t()) :: Plug.Conn.t()
  def handle_error(conn, code, description) do
    code
    |> build_error(description)
    |> respond(conn)
  end

  @doc """
  Handles response with default error code and description
  """
  @spec handle_error(Plug.Conn.t(), atom()) :: map()
  def handle_error(conn, code) do
    code
    |> build_error()
    |> respond(conn)
  end

  @spec build_error(atom()) :: map()
  defp build_error(code) do

    case Map.fetch(@errors, code) do
      {:ok, error} ->
        build(error.code, error.description)
      _ ->
        build(:internal_server_error, code)
    end
  end

  @spec build_error(atom() :: atom(), String.t()) :: map()
  defp build_error(code, description) do
    build(code, description)
  end

  @spec build(String.t(), String.t()) :: map()
  defp build(code, description) do
    Serializer.Error.serialize(code, description)
  end

  @spec respond(atom(), Plug.Conn.t()) :: map()
  defp respond(data, conn) do
    data = Serializer.Response.serialize(data, "error")

    conn
    |> json(data)
    |> halt()
  end

end
