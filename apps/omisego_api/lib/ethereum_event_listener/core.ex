defmodule OmiseGO.API.EthereumEventListener.Core do
  @moduledoc """
  Functional core of event listener
  """

  defstruct current_block_height: nil,
            service_name: nil,
            block_finality_margin: 10,
            get_ethereum_events_callback: nil,
            process_events_callback: nil

  @type t() :: %__MODULE__{
          current_block_height: pos_integer(),
          service_name: atom(),
          block_finality_margin: non_neg_integer(),
          get_ethereum_events_callback: fun(),
          process_events_callback: fun()
        }

  @doc """
  Returns next Ethereum height to get events from.
  """
  @spec next_events_block_height(t(), pos_integer) :: {:get_events, pos_integer(), t()} | {:dont_get_events, t()}
  def next_events_block_height(
        %__MODULE__{
          current_block_height: current_block_height,
          block_finality_margin: block_finality_margin
        } = state,
        next_sync_height
      )
      when next_sync_height == current_block_height + 1 do
    new_state = %{state | current_block_height: next_sync_height}
    {:get_events, next_sync_height - block_finality_margin, new_state}
  end

  def next_events_block_height(%__MODULE__{current_block_height: current_block_height} = state, next_sync_height)
      when next_sync_height <= current_block_height do
    {:dont_get_events, state}
  end
end
