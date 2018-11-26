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

  defmodule PotentialWithholdingReport do
    @moduledoc """
    information send to handle_downloaded_block
    when is problem with downloading block
    """

    defstruct [:blknum, :time]

    @type t :: %__MODULE__{
            blknum: pos_integer,
            time: pos_integer
          }
  end

  defmodule Config do
    @moduledoc false
    defstruct [
      :block_interval,
      :finality_margin,
      maximum_number_of_pending_blocks: 10,
      maximum_block_withholding_time_ms: 0,
      maximum_number_of_unapplied_blocks: 50
    ]

    @type t :: %__MODULE__{
            maximum_number_of_pending_blocks: pos_integer,
            maximum_block_withholding_time_ms: pos_integer,
            maximum_number_of_unapplied_blocks: pos_integer,
            block_interval: pos_integer
          }
  end

  defmodule PotentialWithholding do
    @moduledoc """
    State information to detect block withholding
    and track if block is downloading.
    """
    defstruct time: nil, downloading: false

    @type t :: %__MODULE__{
            time: pos_integer,
            downloading: boolean
          }
  end

  defstruct [
    :eth_height_done_by_blknum,
    :synced_height,
    :last_applied_block,
    :num_of_highest_block_being_downloaded,
    :number_of_blocks_being_downloaded,
    :unapplied_blocks,
    :potential_block_withholdings,
    :config
  ]

  @type t() :: %__MODULE__{
          eth_height_done_by_blknum: map(),
          synced_height: pos_integer(),
          last_applied_block: non_neg_integer,
          num_of_highest_block_being_downloaded: non_neg_integer,
          number_of_blocks_being_downloaded: non_neg_integer,
          unapplied_blocks: %{
            non_neg_integer => OMG.API.Block.t()
          },
          potential_block_withholdings: %{
            non_neg_integer => PotentialWithholding.t()
          },
          config: Config.t()
        }

  @type block_error() ::
          :incorrect_hash
          | :bad_returned_hash
          | :withholding
          | API.Core.recover_tx_error()

  @type init_error() :: :not_at_block_beginning

  @doc """
  Initializes a fresh instance of BlockGetter's state, having `block_number` as last consumed child block,
  using `child_block_interval` when progressing from one child block to another,
  `synced_height` as the root chain height up to witch all published blocked were processed
  and `finality_margin` as number of root chain blocks that may change during an reorg

  Opts can be:
    - `:maximum_number_of_pending_blocks` - how many block should be pulled from the child chain at once (10)
    - `:maximum_block_withholding_time_ms` - how much time should we wait after the first failed pull until we call it a block withholding byzantine condition of the child chain (0 ms)
  """
  @spec init(non_neg_integer, pos_integer, non_neg_integer, non_neg_integer, boolean, Keyword.t()) ::
          {:ok, %__MODULE__{}} | {:error, init_error()}
  def init(
        block_number,
        child_block_interval,
        synced_height,
        finality_margin,
        state_at_block_beginning,
        opts \\ []
      ) do
    if state_at_block_beginning do
      state = %__MODULE__{
        eth_height_done_by_blknum: %{},
        synced_height: synced_height,
        last_applied_block: block_number,
        num_of_highest_block_being_downloaded: block_number,
        number_of_blocks_being_downloaded: 0,
        unapplied_blocks: %{},
        potential_block_withholdings: %{},
        config:
          struct(Config, Keyword.merge(opts, block_interval: child_block_interval, finality_margin: finality_margin))
      }

      {:ok, state}
    else
      {:error, :not_at_block_beginning}
    end
  end

  @doc """
  Marks that child chain block published on `blk_eth_height` was processed
  """
  @spec apply_block(t(), pos_integer()) :: {t(), non_neg_integer(), list()}
  def apply_block(%__MODULE__{eth_height_done_by_blknum: eth_height_done_by_blknum} = state, applied_block_number) do
    _ =
      Logger.debug(fn ->
        "Applied block #{inspect(applied_block_number)}, blknums that finalize eth_heights: #{
          inspect(state.eth_height_done_by_blknum)
        }"
      end)

    case Map.pop(eth_height_done_by_blknum, applied_block_number) do
      # not present - this applied child block doesn't wrap up any eth height
      {nil, _} ->
        {state, state.synced_height, []}

      # present - we need to mark this eth height as processed
      {eth_height_done, updated_map} ->
        # in case of a reorg we do not want to check in with a lower height
        max_synced_height = max(eth_height_done, state.synced_height)

        state = %{
          state
          | synced_height: max_synced_height,
            eth_height_done_by_blknum: updated_map
        }

        {state, max_synced_height, [{:put, :last_block_getter_eth_height, max_synced_height}]}
    end
  end

  @doc """
  Produces root chain block height range to search for events of block submission.
  If the range is not empty it spans from current synced root chain height to `coordinator_height`.
  Empty range case is solved naturally with {a, b}, a > b
  """
  @spec get_eth_range_for_block_submitted_events(t(), non_neg_integer()) :: {pos_integer(), pos_integer()}
  def get_eth_range_for_block_submitted_events(
        %__MODULE__{synced_height: synced_height, config: config},
        coordinator_height
      ) do
    {max(0, synced_height - config.finality_margin), coordinator_height}
  end

  @doc """
  Returns blocks that can be pushed to state or updates the `synced_height` if no new blocks` submissions are found in a range.

  That is the longest continuous range of blocks downloaded from child chain,
  contained in `block_submitted_events`, published on ethereum height not exceeding `coordinator_height` and not pushed to state before.
  """
  @spec get_blocks_to_apply(t(), list(), non_neg_integer()) ::
          {list({Block.t(), non_neg_integer()}), non_neg_integer(), list(), t()}
  def get_blocks_to_apply(
        %__MODULE__{last_applied_block: last_applied} = state,
        block_submitted_events,
        coordinator_height
      ) do
    filtered_submissions = block_submitted_events |> Enum.filter(fn %{blknum: blknum} -> blknum > last_applied end)
    do_get_blocks_to_apply(state, filtered_submissions, coordinator_height)
  end

  defp do_get_blocks_to_apply(%__MODULE__{synced_height: synced_height} = state, _block_submitted_events, older_height)
       when older_height <= synced_height do
    {[], synced_height, [], state}
  end

  defp do_get_blocks_to_apply(%__MODULE__{} = state, [], coordinator_height) do
    db_updates = [{:put, :last_block_getter_eth_height, coordinator_height}]
    {[], coordinator_height, db_updates, %{state | synced_height: coordinator_height}}
  end

  defp do_get_blocks_to_apply(
         %__MODULE__{unapplied_blocks: blocks, config: config} = state,
         block_submissions,
         _coordinator_height
       ) do
    eth_height_done_by_blknum = append_final_blknums(block_submissions, state.eth_height_done_by_blknum)

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
         eth_height_done_by_blknum: eth_height_done_by_blknum,
         last_applied_block: last_applied_block
     }}
  end

  # goes through new submissions and figures out a mapping from blknum to eth_height, where blknum
  # is the **last** child block number submitted at the root chain height it maps to
  # this is later used to sign eth heights off as synced (`apply_block`)
  defp append_final_blknums(new_submissions, current_eth_height_done_by_blknum) do
    new_submissions
    |> Enum.group_by(fn %{eth_height: eth_height} -> eth_height end, fn %{blknum: blknum} -> blknum end)
    |> Enum.into(%{}, fn {eth_height, blknums} ->
      [last_blknum | _] = Enum.sort(blknums, &(&1 >= &2))
      {last_blknum, eth_height}
    end)
    # merging in this order means that in the case of a reorg the old values are overwritten by the changes
    # which makes the last_synced_height more accurate
    |> (&Map.merge(current_eth_height_done_by_blknum, &1)).()
  end

  @doc """
   Returns additional blocks number on which the Core will be waiting.
   The number of expected block is limited by maximum_number_of_pending_blocks.
  """
  @spec get_numbers_of_blocks_to_download(%__MODULE__{}, non_neg_integer) :: {%__MODULE__{}, list(non_neg_integer)}
  def get_numbers_of_blocks_to_download(
        %__MODULE__{
          unapplied_blocks: unapplied_blocks,
          num_of_highest_block_being_downloaded: num_of_highest_block_being_downloaded,
          number_of_blocks_being_downloaded: number_of_blocks_being_downloaded,
          potential_block_withholdings: potential_block_withholdings,
          config: config
        } = state,
        next_child
      ) do
    first_block_number = num_of_highest_block_being_downloaded + config.block_interval

    number_of_empty_slots = config.maximum_number_of_pending_blocks - number_of_blocks_being_downloaded

    potential_block_withholding_numbers =
      potential_block_withholdings
      |> Enum.filter(fn {_, %PotentialWithholding{downloading: downloading}} -> !downloading end)
      |> Enum.map(fn {key, __} -> key end)

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

    [num_of_highest_block_being_downloaded | _] =
      ([num_of_highest_block_being_downloaded] ++ blocks_numbers) |> Enum.sort(&(&1 > &2))

    _ = log_downloading_blocks(next_child, blocks_numbers)

    update_for_witholding =
      potential_block_withholdings
      |> Map.take(blocks_numbers)
      |> Enum.map(fn {key, value} -> {key, Map.put(value, :downloading, true)} end)
      |> Map.new()

    {
      %{
        state
        | number_of_blocks_being_downloaded: length(blocks_numbers) + number_of_blocks_being_downloaded,
          num_of_highest_block_being_downloaded: num_of_highest_block_being_downloaded,
          potential_block_withholdings: Map.merge(potential_block_withholdings, update_for_witholding)
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
    In case of invalid block detection
    Returns InvalidBlock event.
  Third scenario:
    In case of potential withholding block detection
    Returns same state, state with new  potential_block_withholding or BlockWithHolding event
  """
  @spec handle_downloaded_block(
          %__MODULE__{},
          {:ok, OMG.API.Block.t() | PotentialWithholdingReport.t()} | {:error, block_error(), binary(), pos_integer()}
        ) ::
          {:ok | {:needs_stopping, block_error()}, %__MODULE__{},
           [] | list(Event.InvalidBlock.t()) | list(Event.BlockWithholding.t())}
          | {:error, :duplicate | :unexpected_blok}
  def handle_downloaded_block(
        %__MODULE__{
          number_of_blocks_being_downloaded: number_of_blocks_being_downloaded,
          potential_block_withholdings: potential_block_withholdings
        } = state,
        response
      ) do
    blknum = get_blknum(response)

    # if there was a potential withholding registered - mark it as non-downloading. Otherwise noop
    potential_block_withholdings =
      case potential_block_withholdings[blknum] do
        nil ->
          potential_block_withholdings

        potential_block_withholding ->
          Map.put(potential_block_withholdings, blknum, %PotentialWithholding{
            potential_block_withholding
            | downloading: false
          })
      end

    state = %{
      state
      | number_of_blocks_being_downloaded: number_of_blocks_being_downloaded - 1,
        potential_block_withholdings: potential_block_withholdings
    }

    validate_downloaded_block(state, response)
  end

  defp get_blknum({:ok, %{number: number}}), do: number
  defp get_blknum({:ok, %PotentialWithholdingReport{blknum: blknum}}), do: blknum
  defp get_blknum({:error, _error_type, _hash, number}), do: number

  defp validate_downloaded_block(
         %__MODULE__{
           unapplied_blocks: unapplied_blocks,
           num_of_highest_block_being_downloaded: num_of_highest_block_being_downloaded,
           last_applied_block: last_applied_block,
           potential_block_withholdings: potential_block_withholdings
         } = state,
         {:ok, %{number: number} = block}
       ) do
    with :ok <- if(Map.has_key?(unapplied_blocks, number), do: :duplicate, else: :ok),
         :ok <-
           (if last_applied_block < number and number <= num_of_highest_block_being_downloaded do
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

  defp validate_downloaded_block(
         %__MODULE__{} = state,
         {:error, error_type, hash, number}
       ) do
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
         {:ok, %PotentialWithholdingReport{blknum: blknum, time: time}}
       ) do
    %{time: blknum_time} = Map.get(potential_block_withholdings, blknum, %PotentialWithholding{})

    cond do
      blknum_time == nil ->
        potential_block_withholdings = Map.put(potential_block_withholdings, blknum, %PotentialWithholding{time: time})

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
  @spec validate_download_response(
          {:ok, map()} | {:error, block_error()},
          binary(),
          pos_integer(),
          pos_integer(),
          pos_integer()
        ) ::
          {:ok, map | PotentialWithholdingReport.t()}
          | {:error, block_error(), binary(), pos_integer()}
  def validate_download_response(
        {:ok, %{hash: returned_hash, transactions: transactions, number: number}},
        requested_hash,
        requested_number,
        block_timestamp,
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
             timestamp: block_timestamp,
             zero_fee_requirements: zero_fee_requirements
           }},
        else: {:error, :incorrect_hash, requested_hash, requested_number}
    else
      {:error, error_type} ->
        {:error, error_type, requested_hash, requested_number}
    end
  end

  def validate_download_response({:error, _} = error, requested_hash, requested_number, _block_timestamp, time) do
    _ =
      Logger.info(fn ->
        "Detected potential block withholding  #{inspect(error)}, hash: #{inspect(requested_hash |> Base.encode16())}, number: #{
          inspect(requested_number)
        }"
      end)

    {:ok, %PotentialWithholdingReport{blknum: requested_number, time: time}}
  end

  @spec validate_tx_executions(list({Transaction.Recovered.signed_tx_hash_t(), pos_integer, pos_integer}), map) ::
          {:chain_ok, []} | {{:needs_stopping, :tx_execution}, list(Event.InvalidBlock.t())}
  def validate_tx_executions(executions, %{hash: hash, number: blknum}) do
    with nil <- Enum.find(executions, &(!match?({:ok, {_, _, _}}, &1))) do
      {:chain_ok, []}
    else
      {:error, reason} ->
        {{:needs_stopping, {:tx_execution, reason}},
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
  def figure_out_exact_sync_height(_, synced_height, 0), do: synced_height

  def figure_out_exact_sync_height(submissions, synced_height, child_top_block_number) do
    # first get the exact match for the eth_height of top child blknum
    submissions
    |> Enum.find(fn %{blknum: blknum} -> blknum == child_top_block_number end)
    # if it exists - good, if it doesn't - the submission is old and we're probably good
    |> case do
      %{eth_height: exact_height} ->
        # here we need to take into account multiple child submissions in one eth height
        # we can only treat as synced, if all children blocks have been processed
        submissions
        # get all the neighbors of the child block last applied
        |> Enum.filter(fn %{eth_height: eth_height} -> eth_height == exact_height end)
        # get the youngest of neighbors. If there are no submissions there, just assume we've found in previous step
        |> Enum.max_by(fn %{blknum: blknum} -> blknum end)
        # if it is our last applied child block then the eth height is good to go, otherwise back off by one eth block
        |> case do
          %{blknum: ^child_top_block_number} -> exact_height
          _ -> max(0, exact_height - 1)
        end

      nil ->
        _ =
          Logger.warn(fn ->
            "#{inspect(child_top_block_number)} not found in recent submissions #{
              inspect(submissions, limit: :infinity)
            }"
          end)

        synced_height
    end
  end

  @doc """
  Ensures the same block will not be send into WatcherDB again.

  Statefull validity keeps track of consumed blocks in separate than WatcherDB database. These databases
  can get out of sync, and then we don't want to send already consumed blocks which could not succeed due
  key constraints on WatcherDB.
  """
  @spec ensure_block_imported_once(map(), pos_integer, non_neg_integer) :: [OMG.Watcher.DB.Transaction.mined_block()]
  def ensure_block_imported_once(block, eth_height, last_persisted_block)
  def ensure_block_imported_once(block, eth_height, nil), do: ensure_block_imported_once(block, eth_height, 0)

  def ensure_block_imported_once(%{number: number}, _eth_height, last_persisted_block)
      when number <= last_persisted_block,
      do: []

  def ensure_block_imported_once(block, eth_height, _last_persisted_block) do
    [block |> to_mined_block(eth_height)]
  end

  # The purpose of this function is to ensure contract between block_getter and db code
  @spec to_mined_block(map(), pos_integer()) :: OMG.Watcher.DB.Transaction.mined_block()
  defp to_mined_block(block, eth_height) do
    %{
      eth_height: eth_height,
      blknum: block.number,
      blkhash: block.hash,
      timestamp: block.timestamp,
      transactions: block.transactions
    }
  end
end
