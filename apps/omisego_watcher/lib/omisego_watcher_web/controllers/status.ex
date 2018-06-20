defmodule OmiseGOWatcherWeb.Controller.Status do
  @moduledoc """
  Watcher status operations
  """

  use OmiseGOWatcherWeb, :controller

  alias OmiseGO.API.State
  alias OmiseGO.Eth
  alias OmiseGOWatcher.BlockGetter

  @doc """
  Gets plasma network status
  """
  def get(conn, _params) do
    with last_validated_child_block_number <- get_last_validated_child_block_number(),
         last_mined_child_block_number <- get_last_mined_child_block_number(),
         syncing_status <- get_syncing_status(),
         last_mined_child_block_timestamp <- get_last_mined_child_block_timestamp(last_mined_child_block_number) do
      json(conn, %{
        last_validated_child_block_number: last_validated_child_block_number,
        last_mined_child_block_number: last_mined_child_block_number,
        last_mined_child_block_timestamp: last_mined_child_block_timestamp,
        syncing_status: syncing_status
      })
    end
  end

  defp get_last_validated_child_block_number do
    State.get_current_child_block_height()
  end

  defp get_last_mined_child_block_number do
    BlockGetter.get_current_block_number()
  end

  defp get_last_mined_child_block_timestamp(last_mined_child_block_number) do
    {:ok, {_root, created_at}} = Eth.get_child_chain(last_mined_child_block_number)
    created_at
  end

  defp get_syncing_status do
    Eth.syncing?()
  end
end
