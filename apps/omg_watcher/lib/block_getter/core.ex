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

  @default_maximum_number_of_unapplied_blocks 50

  defmodule PotentialWithholding do
    @moduledoc false

    defstruct [:blknum, :time]

    @type t :: %__MODULE__{
            blknum: pos_integer,
            time: pos_integer
          }
  end

  defmodule Config do
    @moduledoc false

    defstruct [
      :maximum_number_of_pending_blocks,
      :maximum_block_withholding_time_ms,
      :maximum_number_of_unapplied_blocks,
      :block_interval
    ]

    @type t :: %__MODULE__{
            maximum_number_of_pending_blocks: pos_integer,
            maximum_block_withholding_time_ms: pos_integer,
            maximum_number_of_unapplied_blocks: pos_integer,
            block_interval: pos_integer
          }
  end

  defstruct [
    :height_sync_blknums,
    :synced_height,
    :last_applied_block,
    :num_of_heighest_block_being_downloaded,
    :number_of_blocks_being_downloaded,
    :unapplied_blocks,
    :potential_block_withholdings,
    :config
  ]

  @type t() :: %__MODULE__{
          height_sync_blknums: MapSet.t(),
          synced_height: pos_integer(),
          last_applied_block: non_neg_integer,
          num_of_heighest_block_being_downloaded: non_neg_integer,
          number_of_blocks_being_downloaded: non_neg_integer,
          unapplied_blocks: %{
            non_neg_integer => OMG.API.Block.t()
          },
          potential_block_withholdings: %{
            non_neg_integer => pos_integer
          },
          config: Config.t()
        }

  @type block_error() ::
          :incorrect_hash
          | :bad_returned_hash
          | :withholding
          | API.Core.recover_tx_error()

  @doc """
  Initializes a fresh instance of BlockGetter's state, having `block_number` as last consumed child block,
  using `child_block_interval` when progressing from one child block to another
  and `synced_height` as the root chain height up to witch all published blocked were processed

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
    config = %Config{
      maximum_number_of_pending_blocks: Keyword.get(opts, :maximum_number_of_pending_blocks, 3),
      maximum_block_withholding_time_ms: Keyword.get(opts, :maximum_block_withholding_time_ms, 0),
      maximum_number_of_unapplied_blocks:
        Keyword.get(opts, :maximum_number_of_unapplied_blocks, @default_maximum_number_of_unapplied_blocks),
      block_interval: child_block_interval
    }

    %__MODULE__{
      height_sync_blknums: MapSet.new(),
      synced_height: synced_height,
      last_applied_block: block_number,
      num_of_heighest_block_being_downloaded: block_number,
      number_of_blocks_being_downloaded: 0,
      unapplied_blocks: %{},
      potential_block_withholdings: %{},
      config: config
    }
  end

  @doc """
  Marks that child chain block published on `blk_eth_height` was processed
  """
  @spec apply_block(t(), pos_integer(), non_neg_integer()) :: {t(), non_neg_integer(), list()}
  def apply_block(%__MODULE__{} = state, consumed_block_number, blk_eth_height) do
    if MapSet.member?(state.height_sync_blknums, consumed_block_number) do
      height_sync_blknums = MapSet.delete(state.height_sync_blknums, consumed_block_number)

      state = %{
        state
        | synced_height: blk_eth_height,
          height_sync_blknums: height_sync_blknums
      }

      {state, blk_eth_height, [{:put, :last_block_getter_eth_height, blk_eth_height}]}
    else
      {state, state.synced_height, []}
    end
  end

  @doc """
  Produces root chain block height range to search for events of block submission.
  If the range is not empty it spans from current synced root chain height to `coordinator_height`.
  Empty range case is solved naturally with {a, b}, a > b
  """
  @spec get_eth_range_for_block_submitted_events(t(), non_neg_integer()) :: {pos_integer(), pos_integer()}
  def get_eth_range_for_block_submitted_events(%__MODULE__{synced_height: synced_height}, coordinator_height) do
    {synced_height + 1, coordinator_height}
  end

  @doc """
  Returns blocks that can be pushed to state.

  That is the longest continous range of blocks downloaded from child chain,
  contained in `block_submitted_events`, published on ethereum height not exceeding `coordinator_height` and not pushed to state before.
  """
  @spec get_blocks_to_apply(t(), list(), non_neg_integer()) ::
          {list({Block.t(), non_neg_integer()}), non_neg_integer(), list(), t()}
  def get_blocks_to_apply(state, block_submitted_events, coordinator_height)

  def get_blocks_to_apply(%__MODULE__{} = state, [], coordinator_height) do
    next_synced_height = max(state.synced_height, coordinator_height)
    state = %{state | synced_height: next_synced_height}
    db_updates = [{:put, :last_block_getter_eth_height, next_synced_height}]
    {[], next_synced_height, db_updates, state}
  end

  def get_blocks_to_apply(
        %__MODULE__{unapplied_blocks: blocks, config: config} = state,
        block_submissions,
        _coordinator_height
      ) do
    height_sync_blknums = get_height_sync_blknums(block_submissions, state.height_sync_blknums)

    block_submissions =
      Enum.into(block_submissions, %{}, fn %{blknum: blknum, eth_height: eth_height} -> {blknum, eth_height} end)

    first_blknum_to_apply = state.last_applied_block + config.block_interval

    blknums_to_apply =
      first_blknum_to_apply
      |> Stream.iterate(&(&1 + config.block_interval))
      |> Enum.take_while(fn blknum -> Map.has_key?(block_submissions, blknum) and Map.has_key?(blocks, blknum) end)

    blocks_to_keep = Map.drop(blocks, blknums_to_apply)
    last_applied_block = List.last([state.last_applied_block] ++ blknums_to_apply)

    blocks_to_apply =
      blknums_to_apply
      |> Enum.map(fn blknum -> {Map.get(blocks, blknum), Map.get(block_submissions, blknum)} end)

    {blocks_to_apply, state.synced_height, [],
     %{
       state
       | unapplied_blocks: blocks_to_keep,
         height_sync_blknums: height_sync_blknums,
         last_applied_block: last_applied_block
     }}
  end

  defp get_height_sync_blknums(submissions, current_height_sync_blknums) do
    submissions
    |> Enum.group_by(fn %{eth_height: eth_height} -> eth_height end, fn %{blknum: blknum} -> blknum end)
    |> Map.to_list()
    |> Enum.map(fn {_, blknums} ->
      [last_blknum | _] = Enum.sort(blknums, &(&1 >= &2))
      last_blknum
    end)
    |> MapSet.new()
    |> MapSet.union(current_height_sync_blknums)
  end

  @doc """
   Returns additional blocks number on which the Core will be waiting.
   The number of expected block is limited by maximum_number_of_pending_blocks.
  """
  @spec get_numbers_of_blocks_to_download(%__MODULE__{}, non_neg_integer) :: {%__MODULE__{}, list(non_neg_integer)}
  def get_numbers_of_blocks_to_download(
        %__MODULE__{
          unapplied_blocks: unapplied_blocks,
          num_of_heighest_block_being_downloaded: num_of_heighest_block_being_downloaded,
          number_of_blocks_being_downloaded: number_of_blocks_being_downloaded,
          potential_block_withholdings: potential_block_withholdings,
          config: config
        } = state,
        next_child
      ) do
    first_block_number = num_of_heighest_block_being_downloaded + config.block_interval

    number_of_empty_slots = config.maximum_number_of_pending_blocks - number_of_blocks_being_downloaded

    potential_block_withholding_numbers = Map.keys(potential_block_withholdings)

    potential_next_block_numbers =
      first_block_number
      |> Stream.iterate(&(&1 + config.block_interval))
      |> Stream.take_while(&(&1 < next_child))
      |> Enum.to_list()

    number_of_blocks_to_download =
      min(
        number_of_empty_slots,
        max(
          0,
          config.maximum_number_of_unapplied_blocks - number_of_blocks_being_downloaded - Map.size(unapplied_blocks)
        )
      )

    blocks_numbers =
      (potential_block_withholding_numbers ++ potential_next_block_numbers)
      |> Enum.take(number_of_blocks_to_download)

    [num_of_heighest_block_being_downloaded | _] =
      ([num_of_heighest_block_being_downloaded] ++ blocks_numbers) |> Enum.sort(&(&1 > &2))

    _ = log_downloading_blocks(next_child, blocks_numbers)

    {
      %{
        state
        | number_of_blocks_being_downloaded: length(blocks_numbers) + number_of_blocks_being_downloaded,
          num_of_heighest_block_being_downloaded: num_of_heighest_block_being_downloaded
      },
      blocks_numbers
    }
  end

  defp log_downloading_blocks(_next_child, []), do: :ok

  defp log_downloading_blocks(next_child, blocks_numbers) do
    Logger.info(fn ->
      "Child chain seen at block \##{inspect(next_child)}. Downloading blocks #{inspect(blocks_numbers)}"
    end)
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
  @spec handle_downloaded_block(
          %__MODULE__{},
          {:ok, OMG.API.Block.t() | PotentialWithholding.t()} | {:error, block_error(), binary(), pos_integer()}
        ) ::
          {:ok | {:needs_stopping, block_error()}, %__MODULE__{},
           [] | list(Event.InvalidBlock.t()) | list(Event.BlockWithholding.t())}
          | {:error, :duplicate | :unexpected_blok}
  def handle_downloaded_block(
        %__MODULE__{number_of_blocks_being_downloaded: number_of_blocks_being_downloaded} = state,
        response
      ) do
    state = %{state | number_of_blocks_being_downloaded: number_of_blocks_being_downloaded - 1}
    validate_downloaded_block(state, response)
  end

  defp validate_downloaded_block(
         %__MODULE__{
           unapplied_blocks: unapplied_blocks,
           num_of_heighest_block_being_downloaded: num_of_heighest_block_being_downloaded,
           last_applied_block: last_applied_block,
           potential_block_withholdings: potential_block_withholdings
         } = state,
         {:ok, %{number: number} = block}
       ) do
    with :ok <- if(Map.has_key?(unapplied_blocks, number), do: :duplicate, else: :ok),
         :ok <-
           (if last_applied_block < number and number <= num_of_heighest_block_being_downloaded do
              :ok
            else
              :unexpected_blok
            end) do
      state = %{
        state
        | unapplied_blocks: Map.put(unapplied_blocks, number, block),
          potential_block_withholdings: Map.delete(potential_block_withholdings, number)
      }

      {:ok, state, []}
    else
      error -> {:error, error}
    end
  end

  defp validate_downloaded_block(%__MODULE__{} = state, {:error, error_type, hash, number}) do
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

  defp validate_downloaded_block(
         %__MODULE__{
           potential_block_withholdings: potential_block_withholdings,
           config: config
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

      time - blknum_time >= config.maximum_block_withholding_time_ms ->
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
  @spec validate_download_response({:ok, map()} | {:error, block_error()}, binary(), pos_integer(), pos_integer()) ::
          {:ok, map | PotentialWithholding.t()}
          | {:error, block_error(), binary(), pos_integer()}
  def validate_download_response(
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
      zero_fee_requirements = transactions |> Enum.reduce(%{}, &add_zero_fee/2)

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

  def validate_download_response({:error, _} = error, requested_hash, requested_number, time) do
    _ =
      Logger.info(fn ->
        "Detected potential block withholding  #{inspect(error)}, hash: #{inspect(requested_hash |> Base.encode16())}, number: #{
          inspect(requested_number)
        }"
      end)

    {:ok, %PotentialWithholding{blknum: requested_number, time: time}}
  end

  @spec validate_tx_executions(list({Transaction.Recovered.signed_tx_hash_t(), pos_integer, pos_integer}), map) ::
          {:ok, []} | {{:needs_stopping, :tx_execution}, list(Event.InvalidBlock.t())}
  def validate_tx_executions(executions, %{hash: hash, number: blknum}) do
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

  defp add_zero_fee(%Transaction.Recovered{signed_tx: %Transaction.Signed{raw_tx: %Transaction{cur12: cur12}}}, fee_map) do
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
