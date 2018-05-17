defmodule OmiseGO.JSONRPC.Helper do
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

  def jsonrpc(url, method, params) do
    JSONRPC2.Clients.HTTP.call(url, to_string(method), params)
  end

  def decode(:bitstring, value), do: Base.decode16!(value)
end
