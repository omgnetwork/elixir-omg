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

defmodule OMG.JSONRPC.Client do
  @moduledoc """
  Encoding and decoding elixir values, see also `OMG.JSONRPC.ExposeSpec`
  """

  def encode(arg) when is_binary(arg), do: Base.encode16(arg)

  def encode(%{__struct__: _} = struct), do: encode(Map.from_struct(struct))

  def encode(arg) when is_map(arg) do
    for {key, value} <- arg, into: %{} do
      {key, encode(value)}
    end
  end

  def encode(arg) when is_list(arg), do: for(value <- arg, into: [], do: encode(value))
  def encode(arg) when is_tuple(arg), do: encode(Tuple.to_list(arg))
  def encode(arg), do: arg

  def get_url do
    Application.get_env(:omg_jsonrpc, :child_chain_url)
  end

  @spec call(atom, map, binary) :: {:error | :ok, any}
  def call(method, params, url \\ get_url()) do
    with {:ok, server_response} <- JSONRPC2.Clients.HTTP.call(url, to_string(method), encode(params)),
         do: decode_payload(method, server_response)
  end

  def decode(:bitstring, arg) when is_binary(arg) do
    case Base.decode16(arg, case: :mixed) do
      :error -> {:error, :argument_decode_error}
      other -> other
    end
  end

  def decode(:bitstring, _arg), do: {:error, :argument_decode_error}
  def decode(_type, arg), do: {:ok, arg}

  defp decode_payload(:get_block, response_payload) do
    with {:ok, %{transactions: encoded_txs, hash: encoded_hash} = atomized_block} <-
           atomize(response_payload, [:hash, :transactions, :number]),
         decode_txs_result = for(tx <- encoded_txs, do: decode(:bitstring, tx)),
         nil <- Enum.find(decode_txs_result, &(!match?({:ok, _}, &1))),
         decoded_txs = Enum.map(decode_txs_result, fn {:ok, tx} -> tx end),
         {:ok, decoded_hash} <- decode(:bitstring, encoded_hash),
         do:
           {:ok,
            %{
              atomized_block
              | transactions: decoded_txs,
                hash: decoded_hash
            }}
  end

  defp decode_payload(:submit, response_payload) do
    with {:ok, %{tx_hash: encoded_tx_hash} = atomized_response} <-
           atomize(response_payload, [:tx_hash, :blknum, :tx_index]),
         {:ok, decoded_tx_hash} <- decode(:bitstring, encoded_tx_hash),
         do: {:ok, %{atomized_response | tx_hash: decoded_tx_hash}}
  end

  defp atomize(map, allowed_atoms) when is_map(map) do
    try do
      {:ok, for({key, value} <- map, into: %{}, do: {String.to_existing_atom(key), value})}
    rescue
      ArgumentError -> {:unexpected_key_in_map, {:got, inspect(map)}, {:expected, allowed_atoms}}
    end
  end
end
