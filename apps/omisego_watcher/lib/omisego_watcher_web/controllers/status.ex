defmodule OmiseGOWatcherWeb.Controller.Status do
  @moduledoc """
  Module provides operation related to childchain health status, like: geth syncing status, last minned block
  number and time and last block verified by watcher.
  """

  use OmiseGOWatcherWeb, :controller

  alias OmiseGO.API.State
  alias OmiseGO.Eth

  action_fallback(OmiseGOWatcherWeb.Controller.JsonFallback)

  @doc """
  Gets plasma network and Watcher status
  """
  def get(conn, _params) do
    with {:ok, last_mined_child_block_number} <- Eth.get_mined_child_block(),
         {:ok, {_root, last_mined_child_block_timestamp}} <- Eth.get_child_chain(last_mined_child_block_number) do
      json(conn, %{
        last_validated_child_block_number: State.get_current_child_block_height(),
        last_mined_child_block_number: last_mined_child_block_number,
        last_mined_child_block_timestamp: last_mined_child_block_timestamp,
        eth_syncing: Eth.syncing?()
      })
    end
  end
end
