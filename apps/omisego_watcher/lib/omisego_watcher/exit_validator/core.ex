defmodule OmiseGOWatcher.ExitValidator.Core do
  @moduledoc """
  Functional core of exit validator
  """

  defstruct synced_height: nil,
            last_exit_block_height: nil,
            margin_on_synced_block: 0,
            update_key: nil,
            utxo_exists_callback: nil,
            service_name: nil

  @type t() :: %__MODULE__{
          synced_height: non_neg_integer(),
          last_exit_block_height: non_neg_integer(),
          margin_on_synced_block: non_neg_integer(),
          update_key: atom(),
          utxo_exists_callback: fun(),
          service_name: atom()
        }

  @doc """
  Returns block height
  """
  @spec next_events_block_height(%__MODULE__{}, pos_integer) :: {pos_integer, %__MODULE__{}, list()} | :empty_range
  def next_events_block_height(
        %__MODULE__{
          synced_height: synced_height,
          margin_on_synced_block: margin_on_synced_block,
          update_key: update_key
        } = state,
        next_synced_height
      ) do
    block_height_to_get_exits_from = max(next_synced_height - margin_on_synced_block, 0)

    if synced_height >= next_synced_height do
      :empty_range
    else
      state = %{
        state
        | last_exit_block_height: block_height_to_get_exits_from,
          synced_height: next_synced_height
      }

      db_updates = [{:put, update_key, block_height_to_get_exits_from}]
      {block_height_to_get_exits_from, state, db_updates}
    end
  end
end
