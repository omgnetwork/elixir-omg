defmodule OmiseGOWatcher.BlockGetter.Core do
  @moduledoc false

  alias OmiseGO.API
  alias OmiseGO.API.Block
  alias OmiseGO.API.State.Transaction
  alias OmiseGOWatcher.Eventer.Event

  use OmiseGO.API.LoggerExt

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

  @type block_error() ::
          :incorrect_hash
          | :bad_returned_hash
          | API.Core.recover_tx_error()

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

    number_of_empty_slots =
      maximum_number_of_pending_blocks - waiting_for_blocks - map_size(potential_block_withholdings)

    blocks_numbers =
      Map.keys(potential_block_withholdings) ++
        (first_block_number
         |> Stream.iterate(&(&1 + block_interval))
         |> Stream.take_while(&(&1 < next_child))
         |> Enum.take(number_of_empty_slots))

    {
      %{
        state
        | waiting_for_blocks: length(blocks_numbers) + waiting_for_blocks,
          started_height_block: hd(([started_height_block] ++ blocks_numbers) |> Enum.sort() |> Enum.take(-1))
      },
      blocks_numbers
    }
  end

  @doc """
  Add block to \"block to consume\" tick off the block from pending blocks.
  Returns the consumable, contiguous list of ordered blocks
  """
  @spec got_block(%__MODULE__{}, {:ok, OmiseGO.API.Block.t()} | {:error, block_error(), binary(), pos_integer()}) ::
          {:ok, %__MODULE__{}, list(OmiseGO.API.Block.t()) | [], nil | Event.InvalidBlock.t()}
          | Event.BlockWithHolding.t()
          | {:error, :duplicate | :unexpected_blok}
  def got_block(
        %__MODULE__{
          block_to_consume: block_to_consume,
          waiting_for_blocks: waiting_for_blocks,
          started_height_block: started_height_block,
          last_consumed_block: last_consumed_block,
          potential_block_withholdings: potential_block_withholdings
        } = state,
        {:ok, %{number: number} = block}
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

      {:ok, state2, list_block_to_consume, []}
    else
      error -> {:error, error}
    end
  end

  def got_block(%__MODULE__{} = state, {:error, error_type, hash, number}) do
    {
      :error,
      state,
      [],
      [
        %Event.InvalidBlock{
          error_type: error_type,
          hash: hash,
          number: number
        }
      ]
    }
  end

  def got_block(
        %__MODULE__{
          potential_block_withholdings: potential_block_withholdings,
          maximum_block_withholding_time: maximum_block_withholding_time,
          waiting_for_blocks: waiting_for_blocks
        } = state,
        {:ok, %PotentialWithholding{blknum: blknum}}
      ) do
    current_time = :os.system_time(:millisecond)
    blknum_time = Map.get(potential_block_withholdings, blknum)

    cond do
      blknum_time == nil ->
        potential_block_withholdings = Map.put(potential_block_withholdings, blknum, current_time)

        state = %{
          state
          | potential_block_withholdings: potential_block_withholdings,
            waiting_for_blocks: waiting_for_blocks - 1
        }

        {:ok, state, [], []}

      current_time - blknum_time > maximum_block_withholding_time ->
        {:error, state, [], [%Event.BlockWithHolding{blknum: blknum}]}

      true ->
        {:ok, state, [], []}
    end
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

  @doc """
  Statelessly decodes and validates a downloaded block, does all the checks before handing off to State.exec-checking
  requested_hash is given to compare to always have a consistent data structure coming out
  requested_number is given to _override_ since we're getting by hash, we can have empty blocks with same hashes!
  """
  @spec decode_validate_block({:ok, map()} | {:error, block_error()}, binary(), pos_integer()) ::
          {:ok, map | PotentialWithholding.t()}
          | {:error, block_error()}
  def decode_validate_block(
        {:ok, %{hash: returned_hash, transactions: transactions, number: number}},
        requested_hash,
        requested_number
      ) do
    with transaction_decode_results <- Enum.map(transactions, &API.Core.recover_tx/1),
         nil <- Enum.find(transaction_decode_results, &(!match?({:ok, _}, &1))),
         transactions <- Enum.map(transaction_decode_results, &elem(&1, 1)),
         true <- returned_hash == requested_hash || {:error, :bad_returned_hash} do
      # hash the block yourself and compare
      %Block{hash: calculated_hash} = Block.hashed_txs_at(transactions, number)

      # we as the Watcher don't care about the fees, so we fix all currencies to require 0 fee
      zero_fee_requirements = transactions |> Enum.reduce(%{}, &zero_fee_for/2)

      if calculated_hash == requested_hash,
        do:
          {:ok,
           %{
             transactions: transactions,
             number: requested_number,
             hash: returned_hash,
             zero_fee_requirements: zero_fee_requirements
           }},
        else: {:error, :incorrect_hash, requested_hash, requested_number}
    else
      {:error, error_type} ->
        {:error, error_type, requested_hash, requested_number}
    end
  end

  def decode_validate_block({:error, _} = error, requested_hash, requested_number) do
    _ =
      Logger.info(fn ->
        "Detected potential block withholding  #{inspect(error)}, hash: #{requested_hash}, number: #{requested_number}"
      end)

    {:ok, %PotentialWithholding{blknum: requested_number}}
  end

  def check_tx_executions(exces, %{hash: hash, number: blknum}) do
    with nil <- Enum.find(exces, &(!match?({:ok, {_, _, _}}, &1))) do
      {:ok, []}
    else
      _ ->
        {:error,
         [
           %Event.InvalidBlock{
             error_type: :tx_execution,
             hash: hash,
             number: blknum
           }
         ]}
    end
  end

  # adds a new zero fee to a map of zero fee requirements
  defp zero_fee_for(%Transaction.Recovered{signed_tx: %Transaction.Signed{raw_tx: %Transaction{cur12: cur12}}}, fee_map) do
    Map.put(fee_map, cur12, 0)
  end
end
