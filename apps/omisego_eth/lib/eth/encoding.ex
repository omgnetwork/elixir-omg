defmodule OmiseGO.Eth.Encoding do
  @moduledoc """
  Internal encoding helpers to talk to ethereum.
  To be used in Eth and DevHelper
  """

  def encode_eth_rpc_unsigned_int(value) do
    "0x" <> (value |> :binary.encode_unsigned() |> Base.encode16() |> String.trim_leading("0"))
  end
end
