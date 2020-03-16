# Copyright 2019-2020 OmiseGO Pte Ltd
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
  @moduledoc """
  Logic module for the `OMG.Watcher.BlockGetter`.

  Responsible for:
    - figuring out the range of child chain blocks needed to be downloaded
    - tracking the block downloading process and signaling withholding if need be
    - doing the stateless validation of blocks (and transactions within those blocks)
    - tracking the progress of stateful validation of blocks
    - matching up `BlockSubmitted` root chain events with the downloaded blocks, to discover submission `eth_height`.
  """

  alias OMG.Block
  alias OMG.State.Transaction
  alias OMG.Watcher.BlockGetter.BlockApplication
  alias OMG.Watcher.Event
  alias OMG.Watcher.ExitProcessor

  use OMG.Utils.LoggerExt

  defmodule Config do
    @moduledoc false
    defstruct [
      :block_interval,
      :block_getter_reorg_margin,
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

  defmodule PotentialWithholdingReport do
    @moduledoc """
    Represents a downloading error interpreted as a potential block withholding event.
    """

    defstruct [:blknum, :hash, :time]

    @type t :: %__MODULE__{
            blknum: pos_integer,
            hash: binary,
            time: pos_integer
          }
  end

  defmodule PotentialWithholding do
    @moduledoc """
    Used to track a recognized potential withholding and track work towards resolving it.
    """
    defstruct time: nil, downloading: false

    @type t :: %__MODULE__{
            time: pos_integer,
            downloading: boolean
          }
  end

  defstruct [
    :synced_height,
    :last_applied_block,
    :num_of_highest_block_being_downloaded,
    :number_of_blocks_being_downloaded,
    :unapplied_blocks,
    :potential_block_withholdings,
    :config,
    :events,
    :chain_status
  ]

  @type t() :: %__MODULE__{
          synced_height: pos_integer(),
          last_applied_block: non_neg_integer,
          num_of_highest_block_being_downloaded: non_neg_integer,
          number_of_blocks_being_downloaded: non_neg_integer,
          unapplied_blocks: %{non_neg_integer => BlockApplication.t()},
          potential_block_withholdings: %{
            non_neg_integer => PotentialWithholding.t()
          },
          config: Config.t(),
          events: block_getter_events_t(),
          chain_status: chain_status_t()
        }

  @type block_getter_event_t() :: Event.InvalidBlock.t() | Event.BlockWithholding.t()
  @type block_getter_events_t() :: list(block_getter_event_t())
  @type chain_status_t() :: :ok | :error

  @type chain_ok_response_t() :: {chain_status_t(), block_getter_events_t()}

  @type block_error() ::
          :incorrect_hash
          | :bad_returned_hash
          | :withholding
          | Transaction.Recovered.recover_tx_error()

  @type init_error() :: :not_at_block_beginning

  @type validate_download_response_result_t() ::
          {:ok, BlockApplication.t() | PotentialWithholdingReport.t()}
          | {:error, {block_error(), binary(), pos_integer()}}

  @doc """
  Initializes a fresh instance of BlockGetter's state, having `block_number` as last consumed child block,
  using `child_block_interval` when progressing from one child block to another,
  `synced_height` as the root chain height up to witch all published blocked were processed
  and `block_getter_reorg_margin` as number of root chain blocks that may change during an reorg.

  Opts can be:
    - `:maximum_number_of_pending_blocks` - how many block should be pulled from the child chain at once (10)
    - `:maximum_block_withholding_time_ms` - how much time should we wait after the first failed pull until we call it
      a block withholding byzantine condition of the child chain (0 ms).
  """
  @spec init(
          non_neg_integer,
          pos_integer,
          non_neg_integer,
          non_neg_integer,
          boolean,
          ExitProcessor.Core.check_validity_result_t(),
          Keyword.t()
        ) :: {:ok, %__MODULE__{}} | {:error, init_error()}
  def init(
        block_number,
        child_block_interval,
        synced_height,
        block_getter_reorg_margin,
        state_at_block_beginning,
        exit_processor_results,
        opts \\ []
      ) do
    with true <- state_at_block_beginning || {:error, :not_at_block_beginning},
         true <- init_opts_valid?(opts) do
      state =
        %__MODULE__{
          synced_height: synced_height,
          last_applied_block: block_number,
          num_of_highest_block_being_downloaded: block_number,
          number_of_blocks_being_downloaded: 0,
          unapplied_blocks: %{},
          potential_block_withholdings: %{},
          config:
            struct(
              Config,
              Keyword.merge(opts,
                block_interval: child_block_interval,
                block_getter_reorg_margin: block_getter_reorg_margin
              )
            ),
          events: [],
          chain_status: :ok
        }
        |> consider_exits(exit_processor_results)

      {:ok, state}
    end
  end

  @doc """
    Returns:
      1. `chain_status` which is based on BlockGetter events and ExitProcessor events
      2. BlockGetter events.
  """
  @spec chain_ok(t()) :: chain_ok_response_t()
  def chain_ok(%__MODULE__{chain_status: chain_status, events: events}), do: {chain_status, events}

  @doc """
  Marks that child chain block published on `eth_height` was processed
  """
  @spec apply_block(t(), BlockApplication.t()) :: {t(), non_neg_integer(), list()}
  def apply_block(%__MODULE__{} = state, %BlockApplication{
        number: blknum,
        eth_height: eth_height,
        eth_height_done: eth_height_done
      }) do
    _ = Logger.debug("\##{inspect(blknum)}, from: #{inspect(eth_height)}, eth height done: #{inspect(eth_height_done)}")

    if eth_height_done do
      # final - we need to mark this eth height as processed
      state = %{state | synced_height: eth_height}
      {state, eth_height, [{:put, :last_block_getter_eth_height, eth_height}]}
    else
      # not final - this applied child block doesn't wrap up any eth height
      {state, state.synced_height, []}
    end
  end

  @doc """
  Produces root chain block height range to search for events of block submission.
  If the range is not empty it spans from current synced root chain height to `coordinator_height`.
  Empty range case is solved naturally with {a, b}, a > b.
  """
  @spec get_eth_range_for_block_submitted_events(t(), non_neg_integer()) :: {pos_integer(), pos_integer()}
  def get_eth_range_for_block_submitted_events(
        %__MODULE__{synced_height: synced_height, config: config},
        coordinator_height
      ) do
    {max(0, synced_height - config.block_getter_reorg_margin), coordinator_height}
  end

  @doc """
  Returns blocks that can be pushed to state or updates the `synced_height` if no new blocks` submissions are found in
  a range.

  That is the longest continuous range of blocks downloaded from child chain, contained in `block_submitted_events`,
  published on ethereum height not exceeding `coordinator_height` and not pushed to state before.
  """
  @spec get_blocks_to_apply(t(), list(), non_neg_integer()) ::
          {list(BlockApplication.t()), non_neg_integer(), list(), t()}
  def get_blocks_to_apply(
        %__MODULE__{last_applied_block: last_applied} = state,
        block_submitted_events,
        coordinator_height
      ) do
    # this ensures that we don't take submissions of already applied blocks into account **at all**
    filtered_submissions = block_submitted_events |> Enum.filter(fn %{blknum: blknum} -> blknum > last_applied end)

    do_get_blocks_to_apply(state, filtered_submissions, coordinator_height)
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
          config: config,
          chain_status: :ok
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

    {%{
       state
       | number_of_blocks_being_downloaded: length(blocks_numbers) + number_of_blocks_being_downloaded,
         num_of_highest_block_being_downloaded: num_of_highest_block_being_downloaded,
         potential_block_withholdings: Map.merge(potential_block_withholdings, update_for_witholding)
     }, blocks_numbers}
  end

  def get_numbers_of_blocks_to_download(state, _next_child) do
    {state, []}
  end

  @doc """
  Statelessly decodes and validates a downloaded block, does all the checks before handing off to State.exec-checking.
  Requested_hash is given to compare to always have a consistent data structure coming out.
  Requested_number is given to _override_ since we're getting by hash, we can have empty blocks with same hashes!
  """
  @spec validate_download_response(
          {:ok, map()} | {:error, block_error()},
          binary(),
          pos_integer(),
          pos_integer(),
          pos_integer()
        ) :: validate_download_response_result_t()
  def validate_download_response(
        {:ok, %{hash: returned_hash, transactions: transactions, number: number}},
        requested_hash,
        requested_number,
        block_timestamp,
        _time
      ) do
    _ =
      Logger.debug(fn ->
        short_hash = returned_hash |> OMG.Eth.Encoding.to_hex() |> Binary.drop(-48)

        "Validating block \##{inspect(requested_number)} #{inspect(short_hash)}... " <>
          "with #{inspect(length(transactions))} txs"
      end)

    with true <- returned_hash == requested_hash || {:error, :bad_returned_hash},
         true <- number == requested_number || {:error, :bad_returned_number},
         {:ok, recovered_txs} <- recover_all_txs(transactions),
         # hash the block yourself and compare
         %Block{hash: calculated_hash} = block = Block.hashed_txs_at(recovered_txs, number),
         true <- calculated_hash == requested_hash || {:error, :incorrect_hash} do
      {:ok, BlockApplication.new(block, recovered_txs, block_timestamp)}
    else
      {:error, reason} -> {:error, {reason, requested_hash, requested_number}}
    end
  end

  def validate_download_response({:error, _} = error, requested_hash, requested_number, _block_timestamp, time) do
    _ = Logger.info("Potential block withholding #{inspect(error)}, number: \##{inspect(requested_number)}")
    {:ok, %PotentialWithholdingReport{blknum: requested_number, hash: requested_hash, time: time}}
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
          {:ok, BlockApplication.t() | PotentialWithholdingReport.t()}
          | {:error, {block_error(), binary(), pos_integer()}}
        ) ::
          {:ok | {:error, block_error()}, %__MODULE__{}}
          | {:error, :duplicate | :unexpected_block}
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

  @spec validate_executions(
          list({Transaction.tx_hash(), pos_integer, pos_integer}),
          map,
          t()
        ) :: {:ok, t()} | {{:error, {:tx_execution, any()}}, t()}
  def validate_executions(tx_execution_results, %{hash: hash, number: blknum}, state) do
    case all_tx_executions_ok?(tx_execution_results) do
      true ->
        {:ok, state}

      {:error, reason} ->
        event = %Event.InvalidBlock{error_type: :tx_execution, hash: hash, blknum: blknum}
        state = state |> set_chain_status(:error) |> add_distinct_event(event)
        {{:error, {:tx_execution, reason}}, state}
    end
  end

  @doc """
  Takes results from `ExitProcessor.check_validity` into account, to potentially stop getting blocks
  """
  @spec consider_exits(t(), ExitProcessor.Core.check_validity_result_t()) :: t()
  def consider_exits(%__MODULE__{} = state, {:ok, _}), do: state

  def consider_exits(%__MODULE__{} = state, {{:error, :unchallenged_exit} = error, _}) do
    _ = Logger.warn("Chain invalid when taking exits into account, because of #{inspect(error)}")
    set_chain_status(state, :error)
  end

  #
  # Private functions
  #

  defp init_opts_valid?(opts) do
    maximum_number_of_pending_blocks = Keyword.get(opts, :maximum_number_of_pending_blocks, 1)
    maximum_number_of_pending_blocks >= 1 || {:error, :maximum_number_of_pending_blocks_too_low}
  end

  # height served as syncable from the `OMG.RootChainCoordinator` is older, nothing we can do about it, so noop
  defp do_get_blocks_to_apply(
         %__MODULE__{synced_height: synced_height} = state,
         _block_submitted_events,
         coordinator_height
       )
       when coordinator_height <= synced_height do
    {[], synced_height, [], state}
  end

  # there are no **non-applied** submissions in the prescribed range of eth-blocks, so let's as much as we can
  defp do_get_blocks_to_apply(%__MODULE__{} = state, [], coordinator_height) do
    db_updates = [{:put, :last_block_getter_eth_height, coordinator_height}]
    {[], coordinator_height, db_updates, %{state | synced_height: coordinator_height}}
  end

  # there are blocks to apply, so let's schedule that. This clause defers advancing the synced_height until apply_block
  defp do_get_blocks_to_apply(
         %__MODULE__{unapplied_blocks: blocks, config: config} = state,
         block_submissions,
         _coordinator_height
       ) do
    eth_height_done_by_blknum = final_blknums(block_submissions)

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
      |> Enum.map(fn blknum ->
        Map.get(blocks, blknum)
        |> Map.put(:eth_height, Map.get(block_submissions, blknum))
        |> Map.put(:eth_height_done, Map.has_key?(eth_height_done_by_blknum, blknum))
        |> struct!()
      end)

    {blocks_to_apply, state.synced_height, [],
     %{
       state
       | unapplied_blocks: blocks_to_keep,
         last_applied_block: last_applied_block
     }}
  end

  # goes through new submissions and figures out a mapping from blknum to eth_height, where blknum
  # is the **last** child block number submitted at the root chain height it maps to
  # this is later used to sign eth heights off as synced (`apply_block`)
  defp final_blknums(new_submissions) do
    new_submissions
    |> Enum.group_by(fn %{eth_height: eth_height} -> eth_height end, fn %{blknum: blknum} -> blknum end)
    |> Enum.into(%{}, fn {eth_height, blknums} ->
      last_blknum = Enum.max(blknums)
      {last_blknum, eth_height}
    end)
  end

  defp log_downloading_blocks(_next_child, []), do: :ok

  defp log_downloading_blocks(next_child, blocks_numbers) do
    Logger.info("Child chain seen at block \##{inspect(next_child)}. Downloading blocks #{inspect(blocks_numbers)}")
  end

  defp get_blknum({:ok, %{number: number}}), do: number
  defp get_blknum({:ok, %PotentialWithholdingReport{blknum: blknum}}), do: blknum
  defp get_blknum({:error, {_error_type, _hash, number}}), do: number

  defp validate_downloaded_block(
         %__MODULE__{
           unapplied_blocks: unapplied_blocks,
           potential_block_withholdings: potential_block_withholdings
         } = state,
         {:ok, %BlockApplication{number: number} = to_apply}
       ) do
    with true <- not_queued_up_yet?(number, unapplied_blocks) || {{:error, :duplicate}, state},
         true <- expected_to_queue_up?(number, state) || {{:error, :unexpected_block}, state} do
      state = %{
        state
        | unapplied_blocks: Map.put(unapplied_blocks, number, to_apply),
          potential_block_withholdings: Map.delete(potential_block_withholdings, number)
      }

      {:ok, state}
    end
  end

  defp validate_downloaded_block(
         %__MODULE__{} = state,
         {:error, {error_type, hash, blknum}}
       ) do
    event = %Event.InvalidBlock{error_type: error_type, hash: hash, blknum: blknum}
    state = state |> set_chain_status(:error) |> add_distinct_event(event)
    {{:error, error_type}, state}
  end

  defp validate_downloaded_block(
         %__MODULE__{
           potential_block_withholdings: potential_block_withholdings,
           config: config
         } = state,
         {:ok, %PotentialWithholdingReport{blknum: blknum, hash: hash, time: time}}
       ) do
    %{time: blknum_time} = Map.get(potential_block_withholdings, blknum, %PotentialWithholding{})

    cond do
      blknum_time == nil ->
        potential_block_withholdings = Map.put(potential_block_withholdings, blknum, %PotentialWithholding{time: time})
        state = %{state | potential_block_withholdings: potential_block_withholdings}
        {:ok, state}

      time - blknum_time >= config.maximum_block_withholding_time_ms ->
        event = %Event.BlockWithholding{blknum: blknum, hash: hash}
        state = state |> set_chain_status(:error) |> add_distinct_event(event)
        {{:error, :withholding}, state}

      true ->
        {:ok, state}
    end
  end

  defp not_queued_up_yet?(number, unapplied_blocks), do: not Map.has_key?(unapplied_blocks, number)

  defp expected_to_queue_up?(number, %{num_of_highest_block_being_downloaded: highest, last_applied_block: last}),
    do: last < number and number <= highest

  defp recover_all_txs(transactions) do
    transactions
    |> Enum.reverse()
    |> Enum.reduce_while({:ok, []}, fn tx, {:ok, recovered_so_far} ->
      case Transaction.Recovered.recover_from(tx) do
        {:ok, recovered} -> {:cont, {:ok, [recovered | recovered_so_far]}}
        other -> {:halt, other}
      end
    end)
  end

  defp all_tx_executions_ok?(tx_execution_results) do
    Enum.find(tx_execution_results, &(!match?({:ok, {_, _, _}}, &1)))
    |> case do
      nil -> true
      other -> other
    end
  end

  defp add_distinct_event(%__MODULE__{events: events} = state, event) do
    if Enum.member?(events, event),
      do: state,
      else: %{state | events: [event | events]}
  end

  defp set_chain_status(state, status), do: %{state | chain_status: status}
end
