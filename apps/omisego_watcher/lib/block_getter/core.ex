defmodule OmiseGOWatcher.BlockGetter.Core do
  @moduledoc false

  alias OmiseGO.API.Block
  alias OmiseGO.API.State.Transaction

  defstruct [
    :last_consumed_block,
    :started_height_block,
    :block_interval,
    :waiting_for_blocks,
    :maximum_number_of_pending_blocks,
    :block_to_consume
  ]

  @type t() :: %__MODULE__{
          last_consumed_block: non_neg_integer,
          started_height_block: non_neg_integer,
          block_interval: pos_integer,
          waiting_for_blocks: non_neg_integer,
          maximum_number_of_pending_blocks: pos_integer,
          block_to_consume: %{non_neg_integer => OmiseGO.API.Block.t()}
        }

  @spec init(non_neg_integer, pos_integer, pos_integer) :: %__MODULE__{}
  def init(block_number, child_block_interval, maximum_number_of_pending_blocks \\ 10) do
    %__MODULE__{
      last_consumed_block: block_number,
      started_height_block: block_number,
      block_interval: child_block_interval,
      waiting_for_blocks: 0,
      maximum_number_of_pending_blocks: maximum_number_of_pending_blocks,
      block_to_consume: %{}
    }
  end

  @doc """
   Returns additional blocks number on which the Core will be waiting.
   The number of expected block is limited by maximum_number_of_pending_blocks.
  """
  @spec get_new_blocks_numbers(%__MODULE__{}, non_neg_integer) :: {%__MODULE__{}, list(non_neg_integer)}
  def get_new_blocks_numbers(
        %__MODULE__{
          started_height_block: started_height_block,
          block_interval: block_interval,
          waiting_for_blocks: waiting_for_blocks,
          maximum_number_of_pending_blocks: maximum_number_of_pending_blocks
        } = state,
        next_child
      ) do
    first_block_number = started_height_block + block_interval
    empty_slot = maximum_number_of_pending_blocks - waiting_for_blocks

    blocks_numbers =
      first_block_number
      |> Stream.iterate(&(&1 + block_interval))
      |> Stream.take_while(&(&1 < next_child))
      |> Enum.take(empty_slot)

    {%{
       state
       | waiting_for_blocks: length(blocks_numbers) + waiting_for_blocks,
         started_height_block: hd(Enum.take([started_height_block] ++ blocks_numbers, -1))
     }, blocks_numbers}
  end

  @doc " add block to \"block to consume\" and decrease number of pending block"
  @spec add_block(%__MODULE__{}, OmiseGO.API.Block.t()) ::
          {:ok, %__MODULE__{}} | {:error, :duplicate | :unexpected_blok}
  def add_block(
        %__MODULE__{
          block_to_consume: block_to_consume,
          waiting_for_blocks: waiting_for_blocks,
          started_height_block: started_height_block,
          last_consumed_block: last_consumed_block
        } = state,
        %Block{number: number} = block
      ) do
    with :ok <- if(Map.has_key?(block_to_consume, number), do: :duplicate, else: :ok),
         :ok <- if(last_consumed_block < number and number <= started_height_block, do: :ok, else: :unexpected_blok) do
      {:ok,
       %{
         state
         | block_to_consume: Map.put(block_to_consume, number, block),
           waiting_for_blocks: waiting_for_blocks - 1
       }}
    else
      error -> {:error, error}
    end
  end

  @doc " Returns a consecutive continuous list of finished blocks."
  @spec get_blocks_to_consume(%__MODULE__{}) :: {%__MODULE__{}, list(OmiseGO.API.Block.t())}
  def get_blocks_to_consume(
        %__MODULE__{
          last_consumed_block: last_consumed_block,
          block_interval: interval,
          block_to_consume: block_to_consume
        } = state
      ) do
    first_block_number = last_consumed_block + interval

    elem =
      first_block_number
      |> Stream.iterate(&(&1 + interval))
      |> Enum.take_while(&Map.has_key?(block_to_consume, &1))

    list_block_to_consume = elem |> Enum.map(&Map.get(block_to_consume, &1))
    new_block_to_consume = Map.drop(block_to_consume, elem)

    {%{state | block_to_consume: new_block_to_consume, last_consumed_block: List.last([last_consumed_block] ++ elem)},
     list_block_to_consume}
  end

  @spec decode_block(block :: map) :: {:ok, Block.t()}
  def decode_block(%{"hash" => hash, "transactions" => transactions, "number" => number}) do
    {:ok,
     %Block{
       transactions:
         transactions
         |> Enum.map(&decode_transaction/1),
       hash: Base.decode16!(hash),
       number: number
     }}
  end

  defp decode_transaction(signed_tx_bytes) do
    {:ok, transaction} = Transaction.Signed.decode(decode(signed_tx_bytes))
    transaction
  end

  defp decode(nil), do: nil
  defp decode(value), do: Base.decode16!(value)
end
