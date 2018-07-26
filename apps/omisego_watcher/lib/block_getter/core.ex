defmodule OmiseGOWatcher.BlockGetter.Core do
  @moduledoc false

  alias OmiseGO.API.Block
  alias OmiseGO.API.State.Transaction

  defmodule PotentialWithholding do
    @moduledoc false

    defstruct [:blknum]

    @type t :: %__MODULE__{
                 blknum: pos_integer
               }
  end

  defstruct [
    :last_consumed_block,
    :started_height_block,
    :block_interval,
    :waiting_for_blocks,
    :maximum_number_of_pending_blocks,
    :block_to_consume,
    :potential_block_withholdings,
    :maximum_block_withholding_time,
    :potential_block_withholding_delay_time
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
          maximum_block_withholding_time: pos_integer,
          potential_block_withholding_delay_time: pos_integer
        }

  @spec init(non_neg_integer, pos_integer, pos_integer) :: %__MODULE__{}
  def init(
        block_number,
        child_block_interval,
        maximum_number_of_pending_blocks \\ 10,
        maximum_block_withholding_time \\ 0,
        potential_block_withholding_delay_time \\ 0
      ) do
    %__MODULE__{
      last_consumed_block: block_number,
      started_height_block: block_number,
      block_interval: child_block_interval,
      waiting_for_blocks: 0,
      maximum_number_of_pending_blocks: maximum_number_of_pending_blocks,
      block_to_consume: %{},
      potential_block_withholdings: %{},
      maximum_block_withholding_time: maximum_block_withholding_time,
      potential_block_withholding_delay_time: potential_block_withholding_delay_time
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
          potential_block_withholdings: potential_block_withholdings,
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
        | waiting_for_blocks: length(blocks_numbers) + waiting_for_blocks,
          started_height_block: hd(Enum.take([started_height_block] ++ blocks_numbers, -1))
      },
      blocks_numbers
    }
  end

  @doc """
  Add block to \"block to consume\" tick off the block from pending blocks.
  Returns the consumable, contiguous list of ordered blocks
  """
  @spec got_block(%__MODULE__{}, OmiseGO.API.Block.t()) ::
          {:ok, %__MODULE__{}, list(OmiseGO.API.Block.t())} | {:error, :duplicate | :unexpected_blok}
  def got_block(
        %__MODULE__{
          block_to_consume: block_to_consume,
          waiting_for_blocks: waiting_for_blocks,
          started_height_block: started_height_block,
          last_consumed_block: last_consumed_block,
          potential_block_withholdings: potential_block_withholdings
        } = state,
        %{number: number} = block
      ) do
    with :ok <- if(Map.has_key?(block_to_consume, number), do: :duplicate, else: :ok),
         :ok <- if(last_consumed_block < number and number <= started_height_block, do: :ok, else: :unexpected_blok) do
      state1 = %{
        state
        | block_to_consume: Map.put(block_to_consume, number, block),
          waiting_for_blocks: waiting_for_blocks - 1
      }

      {state2, list_block_to_consume} = get_blocks_to_consume(state1)

      state2 = %{state2 | potential_block_withholdings: Map.delete(potential_block_withholdings, number)}

      {:ok, state2, list_block_to_consume, nil}
    else
      error -> {:error, error}
    end
  end
# ianvlid block handling
#  def got_block(%__MODULE__{withholdings: withholdings}, %Withholding{number: number}) do
#    # register withholding
#    # mark block number number as "processed" so it is retried _automatically_ whenever get_new_blocks_numbers is called (no additional Task running!)
#    # if too many withholdings return a non-empty list of event_triggers that get streamed into Eventer.notify
#    # {:ok, state, [], either [] (all okay) or [:block_withholding_event_trigger]}
#  end

  def got_block(%__MODULE__{potential_block_withholdings: potential_block_withholdings} = state, %PotentialWithholding{blknum: blknum}) do

    current_time = :os.system_time(:millisecond)
    blknum_time = Map.get(potential_block_withholdings, blknum)

    if blknum_time && current_time - blknum_time > maximum_block_withholding_time do
      {:error, :block_withholding, blknum}
      {:ok, state, [], %Event.BlockWithHolding{blknum: blknum}}

    else
      potential_block_withholdings = Map.put(potential_block_withholdings, blknum, current_time)

      {state, list_block_to_consume} = get_blocks_to_consume(state)

      state = %{state2 | potential_block_withholdings: potential_block_withholdings}

      {:ok, state, list_block_to_consume, nil}
    end

    # register withholding
    # mark block number number as "processed" so it is retried _automatically_ whenever get_new_blocks_numbers is called (no additional Task running!)
    # if too many withholdings return a non-empty list of event_triggers that get streamed into Eventer.notify
    # {:ok, state, [], either [] (all okay) or [:block_withholding_event_trigger]}
  end

  # Returns a consecutive continuous list of finished blocks, that always begins with oldest unconsumed block
  defp get_blocks_to_consume(
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

#  @doc "add potential block withholding"
#  @spec add_potential_block_withholding(%__MODULE__{}, non_neg_integer) ::
#          {:ok, %__MODULE__{}}
#          | {
#              :error,
#              :block_withholding,
#              list(non_neg_integer)
#            }
#  def add_potential_block_withholding(
#        %__MODULE__{
#          potential_block_withholdings: potential_block_withholdings,
#          maximum_block_withholding_time: maximum_block_withholding_time
#        } = state,
#        blknum
#      ) do
#    current_time = :os.system_time(:millisecond)
#    blknum_time = Map.get(potential_block_withholdings, blknum)
#
#    if blknum_time && current_time - blknum_time > maximum_block_withholding_time do
#      {:error, :block_withholding, blknum}
#    else
#      potential_block_withholdings = Map.put(potential_block_withholdings, blknum, current_time)
#      {:ok, %{state | potential_block_withholdings: potential_block_withholdings}}
#    end
#  end
#
#  @doc "remove potential block withholding"
#  @spec remove_potential_block_withholding(%__MODULE__{}, non_neg_integer) :: {%__MODULE__{}}
#  def remove_potential_block_withholding(
#        %__MODULE__{
#          potential_block_withholdings: potential_block_withholdings
#        } = state,
#        blknum
#      ) do
#    potential_block_withholdings = Map.delete(potential_block_withholdings, blknum)
#
#    %{state | potential_block_withholdings: potential_block_withholdings}
#  end

  @doc """
  Statelessly decodes and validates a downloaded block, does all the checks before handing off to State.exec-checking
  requested_hash is given to compare to always have a consistent data structure coming out
  requested_number is given to _override_ since we're getting by hash, we can have empty blocks with same hashes!
  """
  @spec decode_validate_block(block :: map, requested_hash :: binary, requested_number :: pos_integer) ::
          {:ok, map}
          | {:error,
             :incorrect_hash
             | :malformed_transaction_rlp
             | :malformed_transaction
             | :bad_signature_length
             | :hash_decoding_error}
  def decode_validate_block(
        {:ok, %{hash: returned_hash, transactions: transactions, number: number}},
        requested_hash,
        requested_number
      ) do
    with transaction_decode_results <- Enum.map(transactions, &OmiseGO.API.Core.recover_tx/1),
         nil <- Enum.find(transaction_decode_results, &(!match?({:ok, _}, &1))),
         transactions <- Enum.map(transaction_decode_results, &elem(&1, 1)),
         true <- returned_hash == requested_hash || {:error, :bad_returned_hash} do
      # hash the block yourself and compare
      %Block{hash: calculated_hash} = Block.hashed_txs_at(transactions, number)

      zero_fee_requirements =
        transactions
        |> Enum.reduce(%{}, fn tx, fee_map ->
          %Transaction.Recovered{signed_tx: %Transaction.Signed{raw_tx: %Transaction{cur12: cur12}}} = tx
          Map.put(fee_map, cur12, 0)
        end)

      if calculated_hash == requested_hash,
        do:
          {:ok,
           %{
             transactions: transactions,
             number: requested_number,
             hash: returned_hash,
             zero_fee_requirements: zero_fee_requirements
           }},
        else: {:error, :incorrect_hash}
    end
  end

  def decode_validate_block({:error, _}, _requested_hash, requested_number) do
    {:ok, %PotentialWithholding{blknum: requested_number}}
  end

end
