defmodule OMG.Eth.ReleaseTasks.SetContract.EIP55 do
  @moduledoc """
  Implements EIP 55
  """

  @spec encode!(String.t() | binary()) :: String.t()
  def encode!("0x" <> address) when byte_size(address) == 40 do
    address = String.downcase(address)

    hash =
      address
      |> :keccakf1600.sha3_256()
      |> Base.encode16(case: :lower)
      |> String.graphemes()

    encoded =
      address
      |> String.graphemes()
      |> Enum.zip(hash)
      |> Enum.map_join(fn
        {"0", _} -> "0"
        {"1", _} -> "1"
        {"2", _} -> "2"
        {"3", _} -> "3"
        {"4", _} -> "4"
        {"5", _} -> "5"
        {"6", _} -> "6"
        {"7", _} -> "7"
        {"8", _} -> "8"
        {"9", _} -> "9"
        {c, "8"} -> String.upcase(c)
        {c, "9"} -> String.upcase(c)
        {c, "a"} -> String.upcase(c)
        {c, "b"} -> String.upcase(c)
        {c, "c"} -> String.upcase(c)
        {c, "d"} -> String.upcase(c)
        {c, "e"} -> String.upcase(c)
        {c, "f"} -> String.upcase(c)
        {c, _} -> c
      end)

    "0x" <> encoded
  end

  def encode!(address) when byte_size(address) == 20 do
    encode!("0x" <> Base.encode16(address, case: :lower))
  end
end
