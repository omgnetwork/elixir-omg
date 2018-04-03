defmodule OmiseGO.API.Depositor.Core do
  @moduledoc """
  Functional core of depositor
  """

  @block_finality_margin Application.get_env(:omisego_api, :depositor_block_finality_margin)
  @max_blocks_in_fetch Application.get_env(:omisego_api, :depositor_max_block_range_in_deposits_query)
  @get_deposits_interval Application.get_env(:omisego_api, :depositor_get_deposits_interval_ms)

  defstruct last_deposit_block: 1

  def get_deposit_block_range(%__MODULE__{last_deposit_block: last_deposit_block} = state, current_ethereum_block) do
    max_block = current_ethereum_block - @block_finality_margin
    cond do
      max_block <= last_deposit_block ->
        {:no_blocks_with_deposit, state, @get_deposits_interval}
      last_deposit_block + @max_blocks_in_fetch < max_block ->
        next_last_deposit_block = last_deposit_block + @max_blocks_in_fetch
        state = %{state | last_deposit_block: next_last_deposit_block}
        {:ok, state, 0, last_deposit_block + 1, next_last_deposit_block}
      true ->
        state = %{state | last_deposit_block: max_block}
        {:ok, state, @get_deposits_interval, last_deposit_block + 1, max_block}
    end
  end

end
