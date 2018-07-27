defmodule OmiseGOWatcherWeb.TransferChannel do
  @moduledoc """
  Channel Transfer
  """

  use Phoenix.Channel

  def join("transfer:" <> _address, _params, socket) do
    {:ok, socket}
  end

  def join(_, _, _), do: {:error, :invalid_parameter}
end
