# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.Watcher.HttpRPC.Adapter do
  @moduledoc """
  Provides functions to communicate with Child Chain API
  """

  alias OMG.Utils.AppVersion

  require Logger

  @doc """
    Makes HTTP POST request to the API
  """
  def rpc_post(body, path, url) do
    addr = "#{url}/#{path}"
    headers = [{"content-type", "application/json"}, {"X-Watcher-Version", AppVersion.version(:omg_watcher)}]

    with {:ok, body} <- Jason.encode(body),
         {:ok, %HTTPoison.Response{} = response} <- HTTPoison.post(addr, body, headers) do
      _ = Logger.debug("rpc post #{inspect(addr)} completed successfully")
      response
    else
      err ->
        _ = Logger.warn("rpc post #{inspect(addr)} failed with #{inspect(err)}")
        err
    end
  end

  @doc """
  Retrieves body from response structure but don't deserialize it.
  """
  def get_unparsed_response_body({:ok, %HTTPoison.Response{} = response}),
    do: get_unparsed_response_body(response)

  def get_unparsed_response_body(%HTTPoison.Response{status_code: 200, body: body}),
    do: {:ok, body}

  def get_unparsed_response_body(%HTTPoison.Response{body: error}),
    do: {:error, {:client_error, error}}

  def get_unparsed_response_body({:error, %HTTPoison.Error{reason: :econnrefused}}) do
    {:error, :host_unreachable}
  end

  def get_unparsed_response_body({:error, %HTTPoison.Error{reason: reason}}) do
    {:error, {:server_error, reason}}
  end

  def get_unparsed_response_body(error), do: error

  @doc """
  Retrieves body from response structure. When response is successful
  the structure in body is known, so we can try to deserialize it.
  """
  @spec get_response_body(HTTPoison.Response.t() | {:error, HTTPoison.Error.t()}) ::
          {:ok, map()} | {:error, atom() | tuple() | HTTPoison.Error.t()}
  def get_response_body(http_response) do
    with {:ok, body} <- get_unparsed_response_body(http_response),
         {:ok, response} <- Jason.decode(body),
         %{"success" => true, "data" => data} <- response do
      {:ok, convert_keys_to_atoms(data)}
    else
      %{"success" => false, "data" => data} -> {:error, {:client_error, data}}
      error -> error
    end
  end

  defp convert_keys_to_atoms(data) when is_list(data),
    do: Enum.map(data, &convert_keys_to_atoms/1)

  defp convert_keys_to_atoms(data) when is_map(data) do
    data
    |> Stream.map(fn {k, v} -> {String.to_existing_atom(k), v} end)
    |> Map.new()
  end
end
