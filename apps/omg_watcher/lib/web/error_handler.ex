# Copyright 2018 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
  @spec handle_error(Plug.Conn.t(), atom(), String.t()) :: Plug.Conn.t()
  def handle_error(conn, code, description) do
    code
    |> build_error(description)
    |> respond(conn)
  end

  @doc """
  Handles response with default error code and description
  """
  @spec handle_error(Plug.Conn.t(), atom()) :: Plug.Conn.t()
  def handle_error(conn, code) do
    code
    |> build_error()
    |> respond(conn)
  end

  defp build_error(code) do
    case Map.fetch(@errors, code) do
      {:ok, error} ->
        build(error.code, error.description)

      _ ->
        build(:internal_server_error, code)
    end
  end

  defp build_error(code, description) do
    build(code, description)
  end

  defp build(code, description) do
    Serializer.Error.serialize(code, description)
  end

  defp respond(data, conn) do
    data = Serializer.Response.serialize(data, :error)

    conn
    |> json(data)
    |> halt()
  end
end
