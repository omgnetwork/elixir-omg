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

defmodule OMG.RPC.Client do
  @moduledoc """
  Provides functions to communicate with Child Chain API
  """

  require Logger

  @doc """
  Gets Block of given hash
  """
  @spec get_block(binary()) ::
          {:ok, map()}
          | {:error,
             {:malformed_response, any()}
             | {:client_error, any()}
             | {:server_error, any()}}
  def get_block(hash) do
    %{hash: Base.encode16(hash)}
    |> rpc_post("block.get")
    |> get_response_body()
    |> decode_response()
  end

  @doc """
  Submits transaction
  """
  @spec submit(binary()) ::
          {:ok, map()}
          | {:error,
             {:malformed_response, any()}
             | {:client_error, any()}
             | {:server_error, any()}}
  def submit(tx) do
    %{transaction: Base.encode16(tx)}
    |> rpc_post("transaction.submit")
    |> get_response_body()
    |> decode_response()
  end

  @doc """
  Makes HTTP POST request to the API
  """
  def rpc_post(body, path, url \\ nil) do
    url = url || Application.fetch_env!(:omg_watcher, :child_chain_url)
    addr = "#{url}/#{path}"
    headers = [{"content-type", "application/json"}]

    with {:ok, body} <- Poison.encode(body),
         {:ok, %HTTPoison.Response{} = response} <- HTTPoison.post(addr, body, headers) do
      _ = Logger.debug(fn -> "Child chain rpc post #{inspect(addr)} completed successfully" end)
      response
    else
      err ->
        _ = Logger.warn(fn -> "Child chain rpc post #{inspect(addr)} failed with #{inspect(err)}" end)
        err
    end
  end

  # Translates response's body to known elixir structure, either block or tx submission response or error.
  defp decode_response({:ok, %{transactions: transactions, number: number, hash: hash}}) do
    {:ok,
     %{
       number: number,
       hash: Base.decode16!(hash),
       transactions: Enum.map(transactions, &Base.decode16!/1)
     }}
  end

  defp decode_response({:ok, %{tx_hash: _hash} = response}) do
    {:ok, Map.update!(response, :tx_hash, &Base.decode16!/1)}
  end

  defp decode_response(error), do: error

  @doc """
  Retrieves body from response structure. When response is successful
  the structure in body is known, so we can try to deserialize it.
  """
  def get_response_body(%HTTPoison.Response{status_code: 200, body: body}) do
    with {:ok, response} <- Poison.decode(body),
         %{"success" => true, "data" => data} <- response do
      {
        :ok,
        data |> convert_keys_to_atoms()
      }
    else
      %{"success" => false, "data" => data} -> {:error, {:client_error, data}}
      match_err -> {:error, {:malformed_response, match_err}}
    end
  end

  def get_response_body(%HTTPoison.Response{body: error}),
    do: {:error, {:server_error, error}}

  def get_response_body(error), do: {:error, {:client_error, error}}

  defp convert_keys_to_atoms(data) when is_map(data) do
    data
    |> Stream.map(fn {k, v} ->
      {String.to_existing_atom(k), v}
    end)
    |> Map.new()
  end
end
