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

defmodule OMG.Watcher.ChildChainClient do
  @moduledoc """
  Provides functions to communicate with Child Chain API
  """

  alias OMG.API.State.Transaction

  @doc """
  Gets Block of given hash
  """
  @spec get_block(binary()) :: {:ok, map()} | {:error, {atom(), any()}}
  def get_block(hash) do
    %{hash: Base.encode16(hash)}
    |> rpc_post("block.get")
    |> get_response_body()
    |> to_response()
  end

  @doc """
  Submits transaction
  """
  @spec submit(binary()) :: {:ok, map()} | {:error, {atom(), any()}}
  def submit(tx) do
    %{transaction: Base.encode16(tx)}
    |> rpc_post("transaction.submit")
    |> get_response_body()
    |> to_response()
  end

  # Makes HTTP POST request to the API
  defp rpc_post(body, path) do
    url = "#{Application.get_env(:omg_watcher, :child_chain_url)}/#{path}"
    headers = [{"content-type", "application/json"}]

    with {:ok, body} <- Poison.encode(body),
         {:ok, %HTTPoison.Response{} = response} <- HTTPoison.post(url, body, headers) do
      response
    end
  end

  # Translates response's body to known elixir structure, either block or tx submission response or error.
  defp to_response({:ok, %{transactions: transactions, number: number, hash: hash}}) do
    {:ok,
      %{
        number: number,
        hash: Base.decode16!(hash),
        transactions: Enum.map(transactions, &Base.decode16!/1)
      }
    }
  end

  defp to_response({:ok, %{tx_hash: _hash} = response}) do
    {:ok,
      Map.update!(response, :tx_hash, &Base.decode16!/1)
    }
  end

  defp to_response(error), do: error

  # Retrieves body from response structure. When response is successfull
  # the structure in body is known, so we can try to deserialize it.
  defp get_response_body(%HTTPoison.Response{status_code: 200, body: body}) do
    parse_body(body)
  end

  defp get_response_body(%HTTPoison.Response{body: error}),
    do: {:error, {:server_error, error}}

  defp get_response_body(error), do: {:error, {:rpc_post, error}}

  defp parse_body(raw_body) do
    with {:ok, response} <- Poison.decode(raw_body),
         %{"success" => true, "data" => data} <- response do
      {
        :ok,
        data |> str_to_atom()
      }
    else
      {:error, poison_err} -> {:error, {:json_parse, poison_err}}
      %{"success" => false, "data" => data} -> {:error, {:response, data}}
      match_err -> {:error, {:malformed_response, match_err}}
    end
  end

  defp str_to_atom(data) when is_map(data) do
    data
    |> Stream.map(fn {k, v} ->
      {String.to_existing_atom(k), v}
    end)
    |> Map.new()
  end
end
