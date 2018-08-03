defmodule OmiseGO.API.EthereumEventListener.Core do
  @moduledoc """
  Functional core of event listener
  """

  defstruct next_event_height_lower_bound: nil,
            synced_height: nil,
            service_name: nil,
            block_finality_margin: 10,
            get_ethereum_events_callback: nil,
            process_events_callback: nil

  @type t() :: %__MODULE__{
          next_event_height_lower_bound: non_neg_integer(),
          synced_height: non_neg_integer(),
          service_name: atom(),
          block_finality_margin: non_neg_integer(),
          get_ethereum_events_callback: fun(),
          process_events_callback: fun()
        }

  @doc """
  Returns next Ethereum height to get events from.
  """
  @spec next_events_block_range(t(), pos_integer) :: {:get_events, pos_integer(), t()} | {:dont_get_events, t()}
  def next_events_block_range(%__MODULE__{synced_height: synced_height} = state, next_sync_height)
      when next_sync_height <= synced_height do
    {:dont_get_events, state}
  end

  def next_events_block_range(
        %__MODULE__{
          next_event_height_lower_bound: next_event_height_lower_bound,
          block_finality_margin: block_finality_margin
        } = state,
        next_sync_height
      ) do
    next_event_height_upper_bound = next_sync_height - block_finality_margin

    new_state = %{
      state
      | synced_height: next_sync_height,
        next_event_height_lower_bound: next_event_height_upper_bound + 1
    }

    {:get_events, {next_event_height_lower_bound, next_event_height_upper_bound}, new_state}
  end
end
