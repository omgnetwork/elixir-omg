defmodule OmiseGOWatcher.ExitValidator.Core do
  @moduledoc """
  Functional core of exit validator
  """

  defstruct [last_exit_eth_height: nil, synced_eth_height: nil]

  def get_exits_block_range(
    %__MODULE__{
      last_exit_eth_height: last_exit_eth_height,
      synced_eth_height: synced_eth_height
    } = state) when synced_eth_height != nil do
      if last_exit_eth_height <= synced_eth_height do
        :empty_range
      else
        state = %{state | last_exit_eth_height: synced_eth_height}
        {last_exit_eth_height, synced_eth_height, state, [{:put, :last_exit_block_height, synced_eth_height}]}
      end
  end

  def sync_eth_height(%__MODULE__{synced_eth_height: current} = core, synced_eth_height) when current > synced_eth_height do
    %{core | synced_eth_height: synced_eth_height}
  end

end
