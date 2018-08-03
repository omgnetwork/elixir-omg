defmodule OmiseGOWatcherWeb.ByzantineChannel do
  @moduledoc """
  Channel Byzantine is responsible for emitting folllowing events:
  InvalidBlock, BlockWithHolding, InvalidExit
  """

  use Phoenix.Channel

  def join("byzantine", _params, socket) do
    {:ok, socket}
  end

  def join(_, _, _), do: {:error, :invalid_parameter}
end
