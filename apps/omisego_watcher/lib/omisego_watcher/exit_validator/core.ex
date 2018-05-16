defmodule OmiseGOWatcher.ExitValidator.Core do
  @moduledoc """
  Functional core of exit validator
  """

  defstruct last_exit_block_height: nil

  @spec get_exits_block_range(%__MODULE__{}, pos_integer) ::
          {pos_integer, pos_integer, %__MODULE__{}, list()} | :empty_range
  def get_exits_block_range(
        %__MODULE__{last_exit_block_height: last_exit_block_height} = state,
        synced_eth_block_height
      )
      when synced_eth_block_height != nil do
    if last_exit_block_height >= synced_eth_block_height do
      :empty_range
    else
      state = %{state | last_exit_block_height: synced_eth_block_height}

      {last_exit_block_height + 1, synced_eth_block_height, state,
       [{:put, :last_exit_block_height, synced_eth_block_height}]}
    end
  end
end
