defmodule OmiseGO.API.FreshBlocks.Core do
  @moduledoc """
  Logic of the service to serve freshest blocks quickly.
  NOTE: Pending discussion/solution how we're going to really scale this?
  """

  alias OmiseGO.API.Block

  defstruct container: %{}, max_size: 100, keys_queue: :queue.new()

  def get(block_hash, %__MODULE__{} = state) do
    case Map.get(state.container, block_hash) do
      nil -> {nil, [block_hash]}
      %Block{} = block -> {block, []}
    end
  end

  def push(%Block{} = block, %__MODULE__{} = state) do
    keys_queue = :queue.in(block.hash, state.keys_queue)
    container = Map.put(state.container, block.hash, block)

    if state.max_size < Kernel.map_size(container) do
      {{:value, key_to_remove}, keys_queue} = :queue.out(keys_queue)

      {:ok, %{state | keys_queue: keys_queue, container: Map.delete(container, key_to_remove)}}
    else
      {:ok, %{state | keys_queue: keys_queue, container: container}}
    end
  end

  def combine_getting_results(nil = _fresh_block, {:ok, [:not_found] = _fetched_blocks} = _db_result),
    do: {:error, :not_found}

  def combine_getting_results(nil = _fresh_block, {:ok, [db_block] = _fetched_blocks} = _db_result), do: {:ok, db_block}

  def combine_getting_results(fresh_block, _db_result), do: {:ok, fresh_block}
end
