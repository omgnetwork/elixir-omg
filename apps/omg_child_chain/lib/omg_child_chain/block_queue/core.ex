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

defmodule OMG.ChildChain.BlockQueue.Core do
  @moduledoc """
  Logic module for the `OMG.ChildChain.BlockQueue`

  Responsible for
   - keeping a queue of blocks lined up for submission to Ethereum.
   - determining the cadence of forming/submitting blocks to Ethereum.

  Relies on RootChain contract's 'authority' account not being used to send any other transactions, beginning from the
  nonce=1 transaction.

  ### Form block deciding

  Orders to form a new block when:
    - a given number of new Ethereum blocks have been mined (e.g. once every approximately X * 15 seconds) since last
    submission done (`submitBlock` call on the root chain contract), and,
    - there is >= 1 transactions pending in `OMG.State`, that have been successfully executed

  ### Block Queue management

  Keeps track of all the recently formed child chain blocks. Decides when they can be considered definitely mined, in
  light of any reasonably deep reorgs of the root chains. In case resubmission is needed, applies the current gas price.

  Respects the [nonces restriction](https://github.com/omisego/elixir-omg/blob/master/docs/details.md#nonces-restriction)
  mechanism, i.e. the submission nonce is derived from the child chain block number to submit. Currently it is:
  nonce=1 blknum=1000, nonce=2 blknum=2000 etc.
  """
  alias OMG.ChildChain.BlockQueue
  alias OMG.ChildChain.BlockQueue.BlockSubmission
  alias OMG.ChildChain.BlockQueue.Core
  alias OMG.ChildChain.GasPrice

  use OMG.Utils.LoggerExt

  @zero_bytes32 <<0::size(256)>>
  @default_gas_price 20_000_000_000
  @gwei 1_000_000_000

  defstruct [
    :blocks,
    :parent_height,
    :mined_child_block_num,
    :last_enqueued_block_at_height,
    :wait_for_enqueue,
    formed_child_block_num: 0,
    gas_price: @default_gas_price,
    # config:
    child_block_interval: nil,
    block_submit_every_nth: 1,
    block_submit_gas_price_strategy: nil,
    block_submit_max_gas_price: @default_gas_price * 2,
    finality_threshold: 12
  ]

  @type t() :: %__MODULE__{
          blocks: %{pos_integer() => %BlockSubmission{}},
          # last mined block num
          mined_child_block_num: BlockQueue.plasma_block_num(),
          # newest formed block num
          formed_child_block_num: BlockQueue.plasma_block_num(),
          # gas price to use when submitting transactions
          gas_price: pos_integer(),
          # current Ethereum block height
          parent_height: BlockQueue.eth_height(),
          # whether we're pending an enqueue signal with a new block
          wait_for_enqueue: boolean(),
          last_enqueued_block_at_height: pos_integer(),
          # CONFIG CONSTANTS below
          # spacing of child blocks in RootChain contract, being the amount of deposit decimals per child block
          child_block_interval: pos_integer(),
          # configure to trigger forming a child chain block every this many Ethereum blocks are mined since enqueueing
          block_submit_every_nth: pos_integer(),
          # the gas price strategy module to determine the gas price
          block_submit_gas_price_strategy: module(),
          # the maximum gas price to use
          block_submit_max_gas_price: pos_integer(),
          # depth of max reorg we take into account
          finality_threshold: pos_integer()
        }

  @doc """
  Initializes the state of the `OMG.ChildChain.BlockQueue` based on data from `OMG.DB` and configuration
  """
  @spec new(keyword()) ::
          {:ok, Core.t()} | {:error, :contract_ahead_of_db | :mined_blknum_not_found_in_db | :hashes_dont_match}
  def new(opts \\ []) do
    true = Keyword.has_key?(opts, :mined_child_block_num)
    known_hashes = Keyword.fetch!(opts, :known_hashes)
    top_mined_hash = Keyword.fetch!(opts, :top_mined_hash)
    parent_height = Keyword.fetch!(opts, :parent_height)

    fields =
      opts
      |> Keyword.put(:blocks, Map.new())
      |> Keyword.put(:last_enqueued_block_at_height, parent_height)
      |> Keyword.put(:wait_for_enqueue, false)
      |> Keyword.drop([:known_hashes, :top_mined_hash])

    state = struct!(__MODULE__, fields)
    enqueue_existing_blocks(state, top_mined_hash, known_hashes)
  end

  @doc """
  Generates an enumerable of block numbers to be starting the BlockQueue with
  (inclusive and it takes `finality_threshold` blocks before the youngest mined block)
  """
  @spec child_block_nums_to_init_with(non_neg_integer, non_neg_integer, pos_integer, non_neg_integer) :: list
  def child_block_nums_to_init_with(mined_num, until_child_block_num, interval, finality_threshold) do
    first = max(interval, mined_num - finality_threshold * interval)
    last = until_child_block_num
    step = interval
    # :lists.seq/3 throws, so we need to wrap
    if first > last, do: [], else: :lists.seq(first, last, step)
  end

  @doc """
  Sets height of Ethereum chain and the height of the child chain mined on Ethereum.

  Based on that, decides whether new block forming should be triggered as well as the gas price to use for subsequent
  submissions.
  """
  @spec set_ethereum_status(Core.t(), BlockQueue.eth_height(), BlockQueue.plasma_block_num(), boolean()) ::
          {:do_form_block, Core.t()} | {:dont_form_block, Core.t()}
  def set_ethereum_status(state, parent_height, mined_child_block_num, is_empty_block) do
    state =
      state
      |> Map.put(:parent_height, parent_height)
      |> set_mined(mined_child_block_num)

    recalculate_params = [
      blocks: state.blocks,
      parent_height: state.parent_height,
      mined_child_block_num: state.mined_child_block_num,
      formed_child_block_num: state.formed_child_block_num,
      child_block_interval: state.child_block_interval
    ]

    :ok = GasPrice.recalculate_all(recalculate_params)

    strategy = state.block_submit_gas_price_strategy
    max_gas_price = state.block_submit_max_gas_price

    gas_price =
      case GasPrice.get_price(strategy) do
        {:ok, price} when price > max_gas_price ->
          _ = Logger.info("#{__MODULE__}: Gas price from #{strategy} exceeded max_gas_price: #{price / @gwei} gwei. "
            <> "Lowering down to #{state.block_submit_max_gas_price / @gwei} gwei.")
          state.block_submit_max_gas_price

        {:ok, price} ->
          _ = Logger.info("#{__MODULE__}: Gas price from #{strategy} applied: #{price / @gwei} gwei.")
          price

        {:error, :no_gas_price_history} = error ->
          _ = Logger.info("#{__MODULE__}: Gas price from #{strategy} failed: #{inspect(error)}. "
            <> "Using the existing price: #{state.gas_price / @gwei} gwei.")
          state.gas_price
      end

    state = %{state | gas_price: gas_price}

    case should_form_block?(state, is_empty_block) do
      true ->
        {:do_form_block, %{state | wait_for_enqueue: true}}

      false ->
        {:dont_form_block, state}
    end
  end

  @doc """
  Enqueues a new block to the queue of child chain blocks awaiting submission, i.e. ones not yet seen mined.
  """
  @spec enqueue_block(Core.t(), BlockQueue.hash(), BlockQueue.plasma_block_num(), pos_integer()) ::
          Core.t() | {:error, :unexpected_block_number}
  def enqueue_block(state, hash, expected_block_number, parent_height) do
    own_height = state.formed_child_block_num + state.child_block_interval

    with :ok <- validate_block_number(expected_block_number, own_height) do
      do_enqueue_block(state, hash, parent_height)
    end
  end

  @doc """
  Compares the child blocks mined in contract with formed blocks.

  Picks for submission child blocks that haven't yet been seen mined on Ethereum.
  """
  @spec get_blocks_to_submit(Core.t()) :: [BlockQueue.encoded_signed_tx()]
  def get_blocks_to_submit(%{blocks: blocks, formed_child_block_num: formed} = state) do
    _ = Logger.debug("preparing blocks #{inspect(next_blknum_to_mine(state))}..#{inspect(formed)} for submission")

    blocks
    |> Enum.filter(to_mined_block_filter(state))
    |> Enum.map(fn {_blknum, block} -> block end)
    |> Enum.sort_by(& &1.num)
    |> Enum.map(&Map.put(&1, :gas_price, state.gas_price))
  end

  #
  # Private functions
  #

  defp validate_block_number(block_number, block_number), do: :ok
  defp validate_block_number(_, _), do: {:error, :unexpected_block_number}

  defp do_enqueue_block(state, hash, parent_height) do
    own_height = state.formed_child_block_num + state.child_block_interval

    block = %BlockSubmission{
      num: own_height,
      nonce: calc_nonce(own_height, state.child_block_interval),
      hash: hash
    }

    blocks = Map.put(state.blocks, own_height, block)

    %{
      state
      | formed_child_block_num: own_height,
        blocks: blocks,
        wait_for_enqueue: false,
        last_enqueued_block_at_height: parent_height
    }
  end

  # Set number of plasma block mined on the parent chain.

  # Since reorgs are possible, consecutive values of mined_child_block_num don't have to be
  # monotonically increasing. Due to construction of contract we know it does not
  # contain holes so we care only about the highest number.
  @spec set_mined(Core.t(), BlockQueue.plasma_block_num()) :: Core.t()
  defp set_mined(state, mined_child_block_num) do
    num_threshold = mined_child_block_num - state.child_block_interval * state.finality_threshold
    young? = fn {_, block} -> block.num > num_threshold end
    blocks = state.blocks |> Enum.filter(young?) |> Map.new()
    top_known_block = max(mined_child_block_num, state.formed_child_block_num)

    %{state | formed_child_block_num: top_known_block, mined_child_block_num: mined_child_block_num, blocks: blocks}
  end

  @spec next_blknum_to_mine(Core.t()) :: pos_integer()
  defp next_blknum_to_mine(%{mined_child_block_num: mined, child_block_interval: interval}), do: mined + interval

  @spec to_mined_block_filter(Core.t()) :: ({pos_integer, BlockSubmission.t()} -> boolean)
  defp to_mined_block_filter(%{formed_child_block_num: formed} = state),
    do: fn {blknum, _} -> next_blknum_to_mine(state) <= blknum and blknum <= formed end

  @spec should_form_block?(Core.t(), boolean()) :: boolean()
  defp should_form_block?(
         %Core{
           parent_height: parent_height,
           last_enqueued_block_at_height: last_enqueued_block_at_height,
           block_submit_every_nth: block_submit_every_nth,
           wait_for_enqueue: wait_for_enqueue
         },
         is_empty_block
       ) do
    # e.g. if we're at 15th Ethereum block now, last enqueued was at 14th, we're submitting a child chain block on every
    # single Ethereum block (`block_submit_every_nth` == 1), then we could form a new block (`it_is_time` is `true`)
    it_is_time = parent_height - last_enqueued_block_at_height >= block_submit_every_nth
    should_form_block = it_is_time and !wait_for_enqueue and !is_empty_block

    _ =
      if !should_form_block do
        log_data = %{
          parent_height: parent_height,
          last_enqueued_block_at_height: last_enqueued_block_at_height,
          block_submit_every_nth: block_submit_every_nth,
          wait_for_enqueue: wait_for_enqueue,
          it_is_time: it_is_time,
          is_empty_block: is_empty_block
        }

        Logger.debug("Skipping forming block because: #{inspect(log_data)}")
      end

    should_form_block
  end

  defp calc_nonce(height, interval) do
    trunc(height / interval)
  end

  # When restarting, we don't actually know what was the state of submission process to Ethereum.
  # Some blocks might have been submitted and lost/rejected/reorged by Ethereum in the mean time.
  # To properly restart the process we get last blocks known to DB and split them into mined
  # blocks (might still need tracking!) and blocks not yet submitted.

  # NOTE: handles both the case when there aren't any hashes in database and there are
  @spec enqueue_existing_blocks(Core.t(), BlockQueue.hash(), [{pos_integer(), BlockQueue.hash()}]) ::
          {:ok, Core.t()} | {:error, :contract_ahead_of_db | :mined_blknum_not_found_in_db | :hashes_dont_match}
  defp enqueue_existing_blocks(state, @zero_bytes32, [] = _known_hahes) do
    # we start a fresh queue from db and fresh contract
    {:ok, %{state | formed_child_block_num: 0}}
  end

  defp enqueue_existing_blocks(_state, _top_mined_hash, [] = _known_hashes) do
    # something's wrong - no hashes in db and top_mined hash isn't a zero hash as required
    {:error, :contract_ahead_of_db}
  end

  defp enqueue_existing_blocks(state, top_mined_hash, hashes) do
    with :ok <- block_number_and_hash_valid?(top_mined_hash, state.mined_child_block_num, hashes) do
      {mined_blocks, fresh_blocks} = split_existing_blocks(state, hashes)

      mined_submissions =
        for {num, hash} <- mined_blocks do
          {num,
           %BlockSubmission{
             num: num,
             hash: hash,
             nonce: calc_nonce(num, state.child_block_interval)
           }}
        end
        |> Map.new()

      state = %{
        state
        | formed_child_block_num: state.mined_child_block_num,
          blocks: mined_submissions
      }

      _ = Logger.info("Loaded with #{inspect(mined_blocks)} mined and #{inspect(fresh_blocks)} enqueued")

      {:ok, Enum.reduce(fresh_blocks, state, fn hash, acc -> do_enqueue_block(acc, hash, state.parent_height) end)}
    end
  end

  # splits into ones that are before top_mined_hash and those after
  # mined are zipped with their numbers to submit
  defp split_existing_blocks(%__MODULE__{mined_child_block_num: blknum}, blknums_and_hashes) do
    {mined, fresh} =
      Enum.find_index(blknums_and_hashes, &(elem(&1, 0) == blknum))
      |> case do
        nil -> {[], blknums_and_hashes}
        index -> Enum.split(blknums_and_hashes, index + 1)
      end

    fresh_hashes = Enum.map(fresh, &elem(&1, 1))

    {mined, fresh_hashes}
  end

  defp block_number_and_hash_valid?(@zero_bytes32, 0, _) do
    :ok
  end

  defp block_number_and_hash_valid?(expected_hash, blknum, blknums_and_hashes) do
    validate_block_hash(
      expected_hash,
      Enum.find(blknums_and_hashes, fn {num, _hash} -> blknum == num end)
    )
  end

  defp validate_block_hash(expected, {_blknum, blkhash}) when expected == blkhash, do: :ok
  defp validate_block_hash(_, nil), do: {:error, :mined_blknum_not_found_in_db}
  defp validate_block_hash(_, _), do: {:error, :hashes_dont_match}
end
