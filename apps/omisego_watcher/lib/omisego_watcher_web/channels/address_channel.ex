defmodule OmiseGOWatcherWeb.AddressChannel do
  @moduledoc """
  Channel Address
  """

  use Phoenix.Channel

  def join("address:" <> _address, _params, socket) do
    {:ok, socket}
  end

  def join(_, _, _), do: {:error, :invalid_parameter}
end
