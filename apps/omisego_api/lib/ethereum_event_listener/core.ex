defmodule OmiseGO.API.EthereumEventListener.Core do
  @moduledoc """
  Functional core of event listener
  """

  defstruct [last_event_block: 1, block_finality_margin: 10, max_blocks_in_fetch: 5,
             get_events_inerval: 60_000, state_callback: nil]

  def get_events_block_range(
    %__MODULE__{
      last_event_block: last_event_block,
      block_finality_margin: block_finality_margin,
      max_blocks_in_fetch: max_blocks_in_fetch,
      get_events_inerval: get_events_interval
    } = state,
    current_ethereum_block) do

    max_block = current_ethereum_block - block_finality_margin
    cond do
      max_block <= last_event_block ->
        {:no_blocks_with_event, state, get_events_interval}
      last_event_block + max_blocks_in_fetch < max_block ->
        next_last_event_block = last_event_block + max_blocks_in_fetch
        state = %{state | last_event_block: next_last_event_block}
        {:ok, state, 0, last_event_block + 1, next_last_event_block}
      true ->
        state = %{state | last_event_block: max_block}
        {:ok, state, get_events_interval, last_event_block + 1, max_block}
    end
  end

end
