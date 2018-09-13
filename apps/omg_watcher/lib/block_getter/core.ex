# Copyright 2018 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.Watcher.BlockGetter.Core do
  @moduledoc false

  alias OMG.API
  alias OMG.API.Block
  alias OMG.API.State.Transaction
  alias OMG.Watcher.Eventer.Event

  use OMG.API.LoggerExt

  defmodule PotentialWithholding do
    @moduledoc false

    defstruct [:blknum, :time]

    @type t :: %__MODULE__{
            blknum: pos_integer,
            time: pos_integer
          }
  end

  defstruct [
    :synced_height,
    :block_consume_batch,
    :last_consumed_block,
    :started_block_number,
    :block_interval,
    :waiting_for_blocks,
    :maximum_number_of_pending_blocks,
    :blocks_to_consume,
    :potential_block_withholdings,
    :maximum_block_withholding_time_ms
  ]

  @type t() :: %__MODULE__{
          synced_height: pos_integer(),
          block_consume_batch: {atom(), MapSet.t()},
          last_consumed_block: non_neg_integer,
          started_block_number: non_neg_integer,
          block_interval: pos_integer,
          waiting_for_blocks: non_neg_integer,
          maximum_number_of_pending_blocks: pos_integer,
          blocks_to_consume: %{
            non_neg_integer => OMG.API.Block.t()
          },
          potential_block_withholdings: %{
            non_neg_integer => pos_integer
          },
          maximum_block_withholding_time_ms: pos_integer
        }

  @type block_error() ::
          :incorrect_hash
          | :bad_returned_hash
          | :withholding
          | API.Core.recover_tx_error()

  @doc """
  Initializes a fresh instance of BlockGetter's state, having `block_number` as last consumed child block,
  using `child_block_interval` when progressing from one child block to another
  and `synced_height` as the rootchain height up to witch all published blocked were processed

  Opts can be:
    - `:maximum_number_of_pending_blocks` - how many block should be pulled from the child chain at once (10)
    - `:maximum_block_withholding_time_ms` - how much time should we wait after the first failed pull until we call it a block withholding byzantine condition of the child chain (0 ms)
  """
  @spec init(non_neg_integer, pos_integer, non_neg_integer) :: %__MODULE__{}
  def init(
        block_number,
        child_block_interval,
        synced_height,
        opts \\ []
      ) do
    %__MODULE__{
      block_consume_batch: {:downloading, []},
      synced_height: synced_height,
      last_consumed_block: block_number,
      started_block_number: block_number,
      block_interval: child_block_interval,
      waiting_for_blocks: 0,
      maximum_number_of_pending_blocks: Keyword.get(opts, :maximum_number_of_pending_blocks, 10),
      blocks_to_consume: %{},
      potential_block_withholdings: %{},
      maximum_block_withholding_time_ms: Keyword.get(opts, :maximum_block_withholding_time_ms, 0)
    }
  end

  @doc """
  Marks that childchain block `blknum` was processed
  """
  @spec consume_block(t(), pos_integer()) :: t()
  def consume_block(%__MODULE__{} = state, blknum) do
    {:processing, blocks} = state.block_consume_batch
    blocks = MapSet.delete(blocks, blknum)
    blocks_to_consume = Map.delete(state.blocks_to_consume, blknum)
    last_consumed_block = max(state.last_consumed_block, blknum)

    %{
      state
      | block_consume_batch: {:processing, blocks},
        blocks_to_consume: blocks_to_consume,
        last_consumed_block: last_consumed_block
    }
  end

  @doc """
  Produces rootchain block height range to search for events of block submission.
  If the range is not empty it spans from current synced rootchain height to `coordinator_height`.
  """
  @spec get_eth_range_for_block_submitted_events(t(), non_neg_integer()) :: {pos_integer(), pos_integer()}
  def get_eth_range_for_block_submitted_events(%__MODULE__{synced_height: synced_height}, coordinator_height) do
    {synced_height + 1, coordinator_height}
  end

  @spec get_blocks_to_consume(t(), list(), non_neg_integer()) ::
          {list({Block.t(), non_neg_integer()}), non_neg_integer(), list(), t()}
  def get_blocks_to_consume(state, block_submitted_events, coordinator_height)

  def get_blocks_to_consume(%__MODULE__{} = state, [], coordinator_height) do
    next_synced_height = max(state.synced_height, coordinator_height)
    state = %{state | synced_height: next_synced_height}
    db_updates = [{:put, :last_block_getter_eth_height, next_synced_height}]
    {[], next_synced_height, db_updates, state}
  end

  def get_blocks_to_consume(
        %__MODULE__{block_consume_batch: {:downloading, _}, blocks_to_consume: blocks} = state,
        submissions,
        _coordinator_height
      ) do
    blocks_to_consume = get_downloaded_blocks(blocks, submissions)

    # consume blocks only if all blocks submitted to rootchain are downloaded
    if length(blocks_to_consume) == length(submissions) do
      block_consume_batch =
        submissions
        |> Enum.map(& &1.blknum)
        |> MapSet.new()

      state = %{state | block_consume_batch: {:processing, block_consume_batch}}
      {blocks_to_consume, state.synced_height, [], state}
    else
      {[], state.synced_height, [], state}
    end
  end

  def get_blocks_to_consume(
        %__MODULE__{block_consume_batch: {:processing, blocks_to_process}} = state,
        _submissions,
        coordinator_height
      ) do
    if blocks_to_process == MapSet.new() do
      next_synced_height = max(state.synced_height, coordinator_height)
      state = %{state | synced_height: next_synced_height, block_consume_batch: {:downloading, []}}
      db_updates = [{:put, :last_block_getter_eth_height, next_synced_height}]
      {[], next_synced_height, db_updates, state}
    else
      {[], state.synced_height, [], state}
    end
  end

  defp get_downloaded_blocks(downloaded_blocks, requested_blocks) do
    requested_blocks
    |> Enum.map(fn %{blknum: blknum, eth_height: eth_height} -> {Map.get(downloaded_blocks, blknum), eth_height} end)
    |> Enum.filter(fn {block, _} -> block != nil end)
  end

  @doc """
   Returns additional blocks number on which the Core will be waiting.
   The number of expected block is limited by maximum_number_of_pending_blocks.
  """
  @spec get_new_blocks_numbers(%__MODULE__{}, non_neg_integer) :: {%__MODULE__{}, list(non_neg_integer)}
  def get_new_blocks_numbers(
        %__MODULE__{
          started_block_number: started_block_number,
          block_interval: block_interval,
          waiting_for_blocks: waiting_for_blocks,
          potential_block_withholdings: potential_block_withholdings,
          maximum_number_of_pending_blocks: maximum_number_of_pending_blocks
        } = state,
        next_child
      ) do
    first_block_number = started_block_number + block_interval

    number_of_empty_slots = maximum_number_of_pending_blocks - waiting_for_blocks

    potential_block_withholding_numbers = Map.keys(potential_block_withholdings)

    potential_next_block_numbers =
      first_block_number
      |> Stream.iterate(&(&1 + block_interval))
      |> Stream.take_while(&(&1 < next_child))
      |> Enum.to_list()

    blocks_numbers =
      (potential_block_withholding_numbers ++ potential_next_block_numbers)
      |> Enum.take(number_of_empty_slots)

    [started_block_number | _] = ([started_block_number] ++ blocks_numbers) |> Enum.sort(&(&1 > &2))

    {
      %{
        state
        | waiting_for_blocks: length(blocks_numbers) + waiting_for_blocks,
          started_block_number: started_block_number
      },
      blocks_numbers
    }
  end

  @doc """
  First scenario:
    Add block to \"block to consume\" tick off the block from pending blocks.
    Returns the consumable, contiguous list of ordered blocks
  Second scenario:
    In case of invalid block detecion
    Returns InvalidBlock event.
  Thrid scenario:
    In case of potential withholding block detecion
    Returns same state, state with new  potential_block_withholding or BlockWithHolding event
  """
  @spec handle_got_block(
          %__MODULE__{},
          {:ok, OMG.API.Block.t() | PotentialWithholding.t()} | {:error, block_error(), binary(), pos_integer()}
        ) ::
          {:ok | {:needs_stopping, block_error()}, %__MODULE__{},
           [] | list(Event.InvalidBlock.t()) | list(Event.BlockWithholding.t())}
          | {:error, :duplicate | :unexpected_blok}
  def handle_got_block(%__MODULE__{waiting_for_blocks: waiting_for_blocks} = state, response) do
    state = %{state | waiting_for_blocks: waiting_for_blocks - 1}
    validate_got_block(state, response)
  end

  defp validate_got_block(
         %__MODULE__{
           blocks_to_consume: blocks_to_consume,
           started_block_number: started_block_number,
           last_consumed_block: last_consumed_block,
           potential_block_withholdings: potential_block_withholdings
         } = state,
         {:ok, %{number: number} = block}
       ) do
    with :ok <- if(Map.has_key?(blocks_to_consume, number), do: :duplicate, else: :ok),
         :ok <- if(last_consumed_block < number and number <= started_block_number, do: :ok, else: :unexpected_blok) do
      state1 = %{
        state
        | blocks_to_consume: Map.put(blocks_to_consume, number, block)
      }

      state2 = %{state1 | potential_block_withholdings: Map.delete(potential_block_withholdings, number)}

      {:ok, state2, []}
    else
      error -> {:error, error}
    end
  end

  defp validate_got_block(%__MODULE__{} = state, {:error, error_type, hash, number}) do
    {
      {:needs_stopping, error_type},
      state,
      [
        %Event.InvalidBlock{
          error_type: error_type,
          hash: hash,
          number: number
        }
      ]
    }
  end

  defp validate_got_block(
         %__MODULE__{
           potential_block_withholdings: potential_block_withholdings,
           maximum_block_withholding_time_ms: maximum_block_withholding_time_ms
         } = state,
         {:ok, %PotentialWithholding{blknum: blknum, time: time}}
       ) do
    blknum_time = Map.get(potential_block_withholdings, blknum)

    cond do
      blknum_time == nil ->
        potential_block_withholdings = Map.put(potential_block_withholdings, blknum, time)

        state = %{
          state
          | potential_block_withholdings: potential_block_withholdings
        }

        {:ok, state, []}

      time - blknum_time >= maximum_block_withholding_time_ms ->
        {{:needs_stopping, :withholding}, state, [%Event.BlockWithholding{blknum: blknum}]}

      true ->
        {:ok, state, []}
    end
  end

  @doc """
  Statelessly decodes and validates a downloaded block, does all the checks before handing off to State.exec-checking
  requested_hash is given to compare to always have a consistent data structure coming out
  requested_number is given to _override_ since we're getting by hash, we can have empty blocks with same hashes!
  """
  @spec validate_get_block_response({:ok, map()} | {:error, block_error()}, binary(), pos_integer(), pos_integer()) ::
          {:ok, map | PotentialWithholding.t()}
          | {:error, block_error(), binary(), pos_integer()}
  def validate_get_block_response(
        {:ok, %{hash: returned_hash, transactions: transactions, number: number}},
        requested_hash,
        requested_number,
        _time
      ) do
    _ =
      Logger.info(fn ->
        short_hash = returned_hash |> Base.encode16() |> Binary.drop(-48)

        "Validating block \##{inspect(requested_number)} #{short_hash}... with #{inspect(length(transactions))} txs"
      end)

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

  def validate_get_block_response({:error, _} = error, requested_hash, requested_number, time) do
    _ =
      Logger.info(fn ->
        "Detected potential block withholding  #{inspect(error)}, hash: #{requested_hash}, number: #{requested_number}"
      end)

    {:ok, %PotentialWithholding{blknum: requested_number, time: time}}
  end

  @spec check_tx_executions(list({Transaction.Recovered.signed_tx_hash_t(), pos_integer, pos_integer}), map) ::
          {:ok, []} | {{:needs_stopping, :tx_execution}, list(Event.InvalidBlock.t())}
  def check_tx_executions(executions, %{hash: hash, number: blknum}) do
    with nil <- Enum.find(executions, &(!match?({:ok, {_, _, _}}, &1))) do
      {:ok, []}
    else
      _ ->
        {{:needs_stopping, :tx_execution},
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

  @doc """
  Given:
   - a persisted `synced_height` and
   - the actual child block number from `OMG.API.State`
  figures out the exact eth height, which we should begin with. Uses a list of block submission event logs,
  which should contain the `child_top_block_number`'s respective submission.

  This is a workaround for the case where a child block is processed and block number advanced, and eth height isn't.
  This can be the case when the getter crashes after consuming a child block but before it's recognized as synced.

  In case `submissions` doesn't hold the submission of the `child_top_block_number`, it returns the otherwise
  persisted `synced_height`
  """
  @spec figure_out_exact_sync_height([%{blknum: pos_integer, eth_height: pos_integer}], pos_integer, pos_integer) ::
          pos_integer
  def figure_out_exact_sync_height(submissions, synced_height, child_top_block_number) do
    submissions
    |> Enum.find(fn %{blknum: blknum} -> blknum == child_top_block_number end)
    |> case do
      nil -> synced_height
      %{eth_height: exact_height} -> exact_height
    end
  end
end
