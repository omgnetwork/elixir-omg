defmodule OmiseGOWatcherWeb.Controller.Status do
  use OmiseGOWatcherWeb, :controller

  @doc """
  Gets plasma network status
  """
  def get(conn, _params) do
    json(conn, %{
      last_child_block_height: 1000,
      last_mined_block_number: 1000,
      last_mined_block_timestamp: 0,
      syncing_status: :true,
    })
  end
end
