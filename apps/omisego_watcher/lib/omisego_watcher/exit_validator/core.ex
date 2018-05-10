defmodule OmiseGOWatcher.ExitValidator.Core do
  @moduledoc """
  Functional core of exit validator
  """

  defstruct [last_exit_eth_height: nil]

  def get_exits_block_range(
    %__MODULE__{last_exit_eth_height: last_exit_eth_height} = state,
    synced_eth_height) when synced_eth_height != nil do
      if last_exit_eth_height >= synced_eth_height do
        :empty_range
      else
        state = %{state | last_exit_eth_height: synced_eth_height}
        {last_exit_eth_height + 1, synced_eth_height, state, [{:put, :last_exit_block_height, synced_eth_height}]}
      end
  end

end
