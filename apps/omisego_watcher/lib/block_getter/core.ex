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
    :block_to_consume,
    :potential_block_withholdings,
    :maximum_block_withholding_time
  ]

  @type t() :: %__MODULE__{
                 last_consumed_block: non_neg_integer,
                 started_height_block: non_neg_integer,
                 block_interval: pos_integer,
                 waiting_for_blocks: non_neg_integer,
                 maximum_number_of_pending_blocks: pos_integer,
                 block_to_consume: %{
                   non_neg_integer => OmiseGO.API.Block.t()
                 },
                 potential_block_withholdings: %{
                   non_neg_integer => pos_integer
                 },
                 maximum_block_withholding_time: pos_integer
               }

  @spec init(non_neg_integer, pos_integer, pos_integer) :: %__MODULE__{}
  def init(
        block_number,
        child_block_interval,
        maximum_number_of_pending_blocks \\ 10,
        maximum_block_withholding_time \\ 240_000
      ) do
    %__MODULE__{
      last_consumed_block: block_number,
      started_height_block: block_number,
      block_interval: child_block_interval,
      waiting_for_blocks: 0,
      maximum_number_of_pending_blocks: maximum_number_of_pending_blocks,
      block_to_consume: %{},
      potential_block_withholdings: %{},
      maximum_block_withholding_time: maximum_block_withholding_time
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

    {
      %{
        state
      |
        waiting_for_blocks: length(blocks_numbers) + waiting_for_blocks,
        started_height_block: hd(Enum.take([started_height_block] ++ blocks_numbers, -1))
      },
      blocks_numbers
    }
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
      {
        :ok,
        %{
          state
        |
          block_to_consume: Map.put(block_to_consume, number, block),
          waiting_for_blocks: waiting_for_blocks - 1
        }
      }
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

    list_block_to_consume =
      elem
      |> Enum.map(&Map.get(block_to_consume, &1))

    new_block_to_consume = Map.drop(block_to_consume, elem)

    {
      %{state | block_to_consume: new_block_to_consume, last_consumed_block: List.last([last_consumed_block] ++ elem)},
      list_block_to_consume
    }
  end

  @doc "add potential block withholding"
  @spec add_potential_block_withholding(%__MODULE__{}, non_neg_integer) :: {%__MODULE__{}}
  def add_potential_block_withholding(
        %__MODULE__{
          potential_block_withholdings: potential_block_withholdings,
        } = state,
        blknum
      ) do

    current_time = :os.system_time(:millisecond)

    potential_block_withholdings = Map.put_new(potential_block_withholdings, blknum, current_time)

    %{state | potential_block_withholdings: potential_block_withholdings}
  end

  @doc "remove potential block withholding"
  @spec remove_potential_block_withholding(%__MODULE__{}, non_neg_integer) :: {%__MODULE__{}}
  def remove_potential_block_withholding(
        %__MODULE__{
          potential_block_withholdings: potential_block_withholdings,
        } = state,
        blknum
      ) do

    potential_block_withholdings = Map.delete(potential_block_withholdings, blknum)

    %{state | potential_block_withholdings: potential_block_withholdings}
  end

  @doc "check potential block withholdings"
  @spec check_potential_block_withholdings(%__MODULE__{}) :: {:ok, %__MODULE__{}} | {
    :error,
    :block_withholdings,
    list(non_neg_integer)
  }
  def check_potential_block_withholdings(
        %__MODULE__{
          potential_block_withholdings: potential_block_withholdings,
          maximum_block_withholding_time: maximum_block_withholding_time
        } = state
      ) do
    current_time = :os.system_time(:millisecond)

    blknum_withholdings =
      potential_block_withholdings
      |> Enum.filter(fn {_blknum, time} -> current_time - time > maximum_block_withholding_time  end)
      |> Enum.flat_map(fn {blknum, _time} -> [blknum] end)

    if Enum.empty?(blknum_withholdings) do
      {:ok, state}
    else
      {:error, :block_withholdings, blknum_withholdings}
    end

  end

  @spec decode_block(block :: map) :: {:ok, Block.t()} | {:error, :incorrect_hash}
  def decode_block(%{"hash" => hash, "transactions" => transactions, "number" => number}) do
    with transactions <- Enum.map(transactions, &decode_transaction/1),
         nil <- Enum.find(transactions, &(!match?({:ok, _}, &1))),
         transactions <- Enum.map(transactions, &elem(&1, 1)),
         %Block{hash: calculate_hash} = block_with_hash <-
           Block.merkle_hash(%Block{transactions: transactions, number: number}) do
      if {:ok, calculate_hash} == Base.decode16(hash), do: {:ok, block_with_hash}, else: {:error, :incorrect_hash}
    end
  end

  defp decode_transaction(signed_tx_bytes) do
    with {:ok, transaction} <- Base.decode16(signed_tx_bytes),
         {:ok, transaction_sign} <- Transaction.Signed.decode(transaction) do
      Transaction.Recovered.recover_from(transaction_sign)
    end
  end
end
