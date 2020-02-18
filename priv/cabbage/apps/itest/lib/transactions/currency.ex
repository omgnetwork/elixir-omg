defmodule Itest.Transactions.Currency do
  @moduledoc false
  @ether <<0::160>>

  def ether, do: @ether

  def to_wei(ether) when is_binary(ether) do
    ether
    |> String.to_integer()
    |> to_wei()
  end

  def to_wei(ether) when is_integer(ether), do: ether * 1_000_000_000_000_000_000
end
