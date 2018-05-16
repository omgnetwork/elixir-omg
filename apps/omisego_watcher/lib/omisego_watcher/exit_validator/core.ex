defmodule OmiseGOWatcher.ExitValidator.Core do
  @moduledoc """
  Functional core of exit validator
  """

  defstruct last_exit_block_height: nil, margin_on_synced_block: 0, update_key: nil, utxo_exists_callback: nil

  @spec get_exits_block_range(%__MODULE__{}, pos_integer) ::
          {pos_integer, pos_integer, %__MODULE__{}, list()} | :empty_range
  def get_exits_block_range(
        %__MODULE__{
          last_exit_block_height: last_exit_block_height,
          margin_on_synced_block: margin_on_synced_block,
          update_key: update_key
        } = state,
        synced_eth_block_height
      )
      when synced_eth_block_height != nil do
    max_upper_range = synced_eth_block_height - margin_on_synced_block

    if last_exit_block_height >= max_upper_range do
      :empty_range
    else
      state = %{state | last_exit_block_height: max_upper_range}

      {last_exit_block_height + 1, max_upper_range, state, [{:put, update_key, max_upper_range}]}
    end
  end
end
