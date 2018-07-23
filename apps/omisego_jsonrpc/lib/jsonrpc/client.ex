defmodule OmiseGO.JSONRPC.Client do
  @moduledoc """
  helper to encode and decode elixir values
  (see also expose_spec)
  """

  def on_match(_name, :bitstring, value), do: Base.decode16!(value)
  def on_match(_name, _type, value), do: value

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
    jsonrpc_port = Application.get_env(:omisego_jsonrpc, :omisego_api_rpc_port)
    host = Application.get_env(:omisego_jsonrpc, :child_chain_url)
    "#{host}:#{jsonrpc_port}"
  end

  @spec call(atom, map, binary) :: {:error | :ok, any}
  def call(method, params, url \\ get_url()) do
    with {:ok, server_response} <- JSONRPC2.Clients.HTTP.call(url, to_string(method), encode(params)),
         do: decode_payload(method, server_response)
  end

  defp decode(:bitstring, arg) do
    case Base.decode16(arg, case: :mixed) do
      :error -> {:error, :argument_decode_error}
      other -> other
    end
  end

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
