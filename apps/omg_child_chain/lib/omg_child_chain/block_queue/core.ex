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
  Responsible for keeping a queue of blocks lined up for submission to Ethereum.
  Responsible for determining the cadence of forming/submitting blocks to Ethereum.
  Responsible for determining correct gas price and ensuring submissions get mined eventually.

  In particular responsible for picking up, where it's left off (crashed) gracefully.

  Relies on RootChain contract having reorg protection ('decimals for deposits' part).
  Relies on RootChain contract's 'authority' account not being used to send any other transaction.

  Calculates gas price and resubmits block submission transactions not being mined, using a higher gas price.
  See [section](#gas-price-selection)

  Note that first nonce (zero) of authority account is used to deploy RootChain.
  Every next nonce is used to submit operator blocks.

  This is the functional core: has no side-effects or side-causes, for the effectful shell see `OMG.ChildChain.BlockQueue`

  ### Gas price selection

  The mechanism employed is minimalistic, aiming at:
    - pushing formed block submissions as reliably as possible, avoiding delayed mining of submissions as much as possible
    - saving Ether only when certain that we're overpaying
    - being simple and avoiding any external factors driving the mechanism

  The mechanics goes as follows:

  If:
    - we've got a new child block formed, whose submission isn't yet mined and
    - it's been more than 2 (`OMG.ChildChain.BlockQueue.GasPriceAdjustment.eth_gap_without_child_blocks`) root chain blocks
    since a submission has last been seen mined

  the gas price is raised by a factor of 2 (`OMG.ChildChain.BlockQueue.GasPriceAdjustment.gas_price_raising_factor`)

  **NOTE** there's also an upper limit for the gas price (`OMG.ChildChain.BlockQueue.GasPriceAdjustment.max_gas_price`)

  If:
    - we've got a new child block formed, whose submission isn't yet mined and
    - it's been no more than 2 (`OMG.ChildChain.BlockQueue.GasPriceAdjustment.eth_gap_without_child_blocks`) root chain blocks
    since a submission has last been seen mined

  the gas price is lowered by a factor of 0.9 ('OMG.ChildChain.BlockQueue.GasPriceAdjustment.gas_price_lowering_factor')
  """

  alias OMG.ChildChain.BlockQueue
  alias OMG.ChildChain.BlockQueue.Core
  alias OMG.ChildChain.BlockQueue.GasPriceAdjustment

  use OMG.Utils.LoggerExt

  defmodule BlockSubmission do
    @moduledoc false

    @type hash() :: <<_::256>>
    @type plasma_block_num() :: non_neg_integer()

    @type t() :: %__MODULE__{
            num: plasma_block_num(),
            hash: hash(),
            nonce: non_neg_integer(),
            gas_price: pos_integer()
          }
    defstruct [:num, :hash, :nonce, :gas_price]
  end

  @zero_bytes32 <<0::size(256)>>

  defstruct [
    :blocks,
    :parent_height,
    :mined_child_block_num,
    :last_enqueued_block_at_height,
    :wait_for_enqueue,
    last_parent_height: 0,
    formed_child_block_num: 0,
    gas_price_to_use: 20_000_000_000,
    # config:
    child_block_interval: nil,
    block_submit_every_nth: 1,
    finality_threshold: 12,
    gas_price_adj_params: %GasPriceAdjustment{}
  ]

  @type t() :: %__MODULE__{
          blocks: %{pos_integer() => %BlockSubmission{}},
          # last mined block num
          mined_child_block_num: BlockQueue.plasma_block_num(),
          # newest formed block num
          formed_child_block_num: BlockQueue.plasma_block_num(),
          # current Ethereum block height
          parent_height: BlockQueue.eth_height(),
          # whether we're pending an enqueue signal with a new block
          wait_for_enqueue: boolean(),
          # gas price to use when (re)submitting transactions
          gas_price_to_use: pos_integer(),
          last_enqueued_block_at_height: pos_integer(),
          # CONFIG CONSTANTS below
          # spacing of child blocks in RootChain contract, being the amount of deposit decimals per child block
          child_block_interval: pos_integer(),
          # configure to trigger forming a child chain block every this many Ethereum blocks are mined since enqueueing
          block_submit_every_nth: pos_integer(),
          # depth of max reorg we take into account
          finality_threshold: pos_integer(),
          # the gas price adjustment strategy parameters
          gas_price_adj_params: GasPriceAdjustment.t(),
          last_parent_height: non_neg_integer()
        }

  @type submit_result_t() :: {:ok, <<_::256>>} | {:error, map}

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

  @spec enqueue_block(Core.t(), BlockQueue.hash(), BlockQueue.plasma_block_num(), pos_integer()) ::
          Core.t() | {:error, :unexpected_block_number}
  def enqueue_block(state, hash, expected_block_number, parent_height) do
    own_height = state.formed_child_block_num + state.child_block_interval

    with :ok <- validate_block_number(expected_block_number, own_height) do
      enqueue_block(state, hash, parent_height)
    end
  end

  defp validate_block_number(block_number, block_number), do: :ok
  defp validate_block_number(_, _), do: {:error, :unexpected_block_number}

  defp enqueue_block(state, hash, parent_height) do
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

  @doc """
  Set height of Ethereum chain and the height of the child chain mined on Ethereum.
  """
  @spec set_ethereum_status(Core.t(), BlockQueue.eth_height(), BlockQueue.plasma_block_num(), boolean()) ::
          {:do_form_block, Core.t()} | {:dont_form_block, Core.t()}
  def set_ethereum_status(state, parent_height, mined_child_block_num, is_empty_block) do
    new_state =
      %{state | parent_height: parent_height}
      |> set_mined(mined_child_block_num)
      |> adjust_gas_price()

    if should_form_block?(new_state, is_empty_block) do
      {:do_form_block, %{new_state | wait_for_enqueue: true}}
    else
      {:dont_form_block, new_state}
    end
  end

  # Updates gas price to use basing on :calculate_gas_price function, updates current parent height
  # and last mined child block number in the state which used by gas price calculations
  @spec adjust_gas_price(Core.t()) :: Core.t()
  defp adjust_gas_price(%Core{gas_price_adj_params: %GasPriceAdjustment{last_block_mined: nil} = gas_params} = state) do
    # initializes last block mined
    %{
      state
      | gas_price_adj_params: GasPriceAdjustment.with(gas_params, state.parent_height, state.mined_child_block_num)
    }
  end

  defp adjust_gas_price(
         %Core{blocks: blocks, parent_height: parent_height, last_parent_height: last_parent_height} = state
       ) do
    if parent_height <= last_parent_height or
         !Enum.find(blocks, to_mined_block_filter(state)) do
      state
    else
      new_gas_price = calculate_gas_price(state)
      _ = Logger.debug("using new gas price '#{inspect(new_gas_price)}'")

      new_state =
        state
        |> set_gas_price(new_gas_price)
        |> update_last_checked_mined_block_num()

      %{new_state | last_parent_height: parent_height}
    end
  end

  # Calculates the gas price basing on simple strategy to raise the gas price by gas_price_raising_factor
  # when gap of mined parent blocks is growing and droping the price by gas_price_lowering_factor otherwise
  @spec calculate_gas_price(Core.t()) :: pos_integer()
  defp calculate_gas_price(%Core{
         formed_child_block_num: formed_child_block_num,
         mined_child_block_num: mined_child_block_num,
         gas_price_to_use: gas_price_to_use,
         parent_height: parent_height,
         gas_price_adj_params: %GasPriceAdjustment{
           gas_price_lowering_factor: gas_price_lowering_factor,
           gas_price_raising_factor: gas_price_raising_factor,
           eth_gap_without_child_blocks: eth_gap_without_child_blocks,
           max_gas_price: max_gas_price,
           last_block_mined: {lastchecked_parent_height, lastchecked_mined_block_num}
         }
       }) do
    multiplier =
      with true <- blocks_needs_be_mined?(formed_child_block_num, mined_child_block_num),
           true <- eth_blocks_gap_filled?(parent_height, lastchecked_parent_height, eth_gap_without_child_blocks),
           false <- new_blocks_mined?(mined_child_block_num, lastchecked_mined_block_num) do
        gas_price_raising_factor
      else
        _ -> gas_price_lowering_factor
      end

    Kernel.min(
      max_gas_price,
      Kernel.round(multiplier * gas_price_to_use)
    )
  end

  # Updates the state with information about last parent height and mined child block number
  @spec update_last_checked_mined_block_num(Core.t()) :: Core.t()
  defp update_last_checked_mined_block_num(
         %Core{
           parent_height: parent_height,
           mined_child_block_num: mined_child_block_num,
           gas_price_adj_params: %GasPriceAdjustment{
             last_block_mined: {_lastechecked_parent_height, lastchecked_mined_block_num}
           }
         } = state
       ) do
    if lastchecked_mined_block_num < mined_child_block_num do
      %Core{
        state
        | gas_price_adj_params:
            GasPriceAdjustment.with(state.gas_price_adj_params, parent_height, mined_child_block_num)
      }
    else
      state
    end
  end

  defp blocks_needs_be_mined?(formed_child_block_num, mined_child_block_num) do
    formed_child_block_num > mined_child_block_num
  end

  defp eth_blocks_gap_filled?(parent_height, last_height, eth_gap_without_child_blocks) do
    parent_height - last_height >= eth_gap_without_child_blocks
  end

  defp new_blocks_mined?(mined_child_block_num, last_mined_block_num) do
    mined_child_block_num > last_mined_block_num
  end

  defp set_gas_price(state, price) do
    %{state | gas_price_to_use: price}
  end

  @doc """
  Compares the child blocks mined in contract with formed blocks

  Picks for submission child blocks that haven't yet been seen mined on Ethereum
  """
  @spec get_blocks_to_submit(Core.t()) :: [BlockQueue.encoded_signed_tx()]
  def get_blocks_to_submit(%{blocks: blocks, formed_child_block_num: formed} = state) do
    _ = Logger.debug("preparing blocks #{inspect(first_to_mined(state))}..#{inspect(formed)} for submission")

    blocks
    |> Enum.filter(to_mined_block_filter(state))
    |> Enum.map(fn {_blknum, block} -> block end)
    |> Enum.sort_by(& &1.num)
    |> Enum.map(&Map.put(&1, :gas_price, state.gas_price_to_use))
  end

  @spec first_to_mined(Core.t()) :: pos_integer()
  defp first_to_mined(%{mined_child_block_num: mined, child_block_interval: interval}), do: mined + interval

  @spec to_mined_block_filter(Core.t()) :: ({pos_integer, BlockSubmission.t()} -> boolean)
  defp to_mined_block_filter(%{formed_child_block_num: formed} = state),
    do: fn {blknum, _} -> first_to_mined(state) <= blknum and blknum <= formed end

  @doc """
  Generates an enumberable of block numbers to be starting the BlockQueue with
  (inclusive and it takes `finality_threshold` blocks before the youngest mined block)
  """
  @spec child_block_nums_to_init_with(non_neg_integer, non_neg_integer, pos_integer, non_neg_integer) :: list
  def child_block_nums_to_init_with(mined_num, until_child_block_num, interval, finality_threshold) do
    make_range(max(interval, mined_num - finality_threshold * interval), until_child_block_num, interval)
  end

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

  # :lists.seq/3 throws, so wrapper
  defp make_range(first, last, _) when first > last, do: []

  defp make_range(first, last, step) do
    :lists.seq(first, last, step)
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

      {:ok, Enum.reduce(fresh_blocks, state, fn hash, acc -> enqueue_block(acc, hash, state.parent_height) end)}
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

  # TODO: consider moving this logic to separate module
  @spec process_submit_result(BlockSubmission.t(), submit_result_t(), BlockSubmission.plasma_block_num()) ::
          :ok | {:error, atom}
  def process_submit_result(submission, submit_result, newest_mined_blknum)

  def process_submit_result(submission, {:ok, txhash}, _newest_mined_blknum) do
    log_success(submission, txhash)
    :ok
  end

  def process_submit_result(
        submission,
        {:error, %{"code" => -32_000, "message" => "known transaction" <> _}},
        _newest_mined_blknum
      ) do
    log_known_tx(submission)
    :ok
  end

  # parity error code for duplicated tx
  def process_submit_result(
        submission,
        {:error, %{"code" => -32_010, "message" => "Transaction with the same hash was already imported."}},
        _newest_mined_blknum
      ) do
    log_known_tx(submission)
    :ok
  end

  def process_submit_result(
        submission,
        {:error, %{"code" => -32_000, "message" => "replacement transaction underpriced"}},
        _newest_mined_blknum
      ) do
    log_low_replacement_price(submission)
    :ok
  end

  # parity version
  def process_submit_result(
        submission,
        {:error, %{"code" => -32_010, "message" => "Transaction gas price is too low. There is another" <> _}},
        _newest_mined_blknum
      ) do
    log_low_replacement_price(submission)
    :ok
  end

  def process_submit_result(
        submission,
        {:error, %{"code" => -32_000, "message" => "authentication needed: password or unlock"}},
        newest_mined_blknum
      ) do
    diagnostic = prepare_diagnostic(submission, newest_mined_blknum)
    log_locked(diagnostic)
    {:error, :account_locked}
  end

  def process_submit_result(
        submission,
        {:error, %{"code" => -32_000, "message" => "nonce too low"}},
        newest_mined_blknum
      ) do
    process_nonce_too_low(submission, newest_mined_blknum)
  end

  # parity specific error for nonce-too-low
  def process_submit_result(
        submission,
        {:error, %{"code" => -32_010, "message" => "Transaction nonce is too low." <> _}},
        newest_mined_blknum
      ) do
    process_nonce_too_low(submission, newest_mined_blknum)
  end

  # ganache has this error, but these are valid nonce_too_low errors, that just don't make any sense
  # `process_nonce_too_low/2` would mark it as a genuine failure and crash the BlockQueue :(
  # however, everything seems to just work regardless, things get retried and mined eventually
  # NOTE: we decide to degrade the severity to warn and continue, considering it's just `ganache`
  def process_submit_result(
        _submission,
        {:error, %{"code" => -32_000, "data" => %{"stack" => "n: the tx doesn't have the correct nonce" <> _}}} = error,
        _newest_mined_blknum
      ) do
    log_ganache_nonce_too_low(error)
    :ok
  end

  defp log_ganache_nonce_too_low(error) do
    # runtime sanity check if we're actually running `ganache`, if we aren't and we're here, we must crash
    :ganache = Application.fetch_env!(:omg_eth, :eth_node)
    _ = Logger.warn(inspect(error))
    :ok
  end

  defp log_success(submission, txhash) do
    _ = Logger.info("Submitted #{inspect(submission)} at: #{inspect(txhash)}")
    :ok
  end

  defp log_known_tx(submission) do
    _ = Logger.debug("Submission #{inspect(submission)} is known transaction - ignored")
    :ok
  end

  defp log_low_replacement_price(submission) do
    _ = Logger.debug("Submission #{inspect(submission)} is known, but with higher price - ignored")
    :ok
  end

  defp log_locked(diagnostic) do
    _ = Logger.error("It seems that authority account is locked: #{inspect(diagnostic)}. Check README.md")
    :ok
  end

  defp process_nonce_too_low(%BlockSubmission{num: blknum} = submission, newest_mined_blknum) do
    if blknum <= newest_mined_blknum do
      # apparently the `nonce too low` error is related to the submission having been mined while it was prepared
      :ok
    else
      diagnostic = prepare_diagnostic(submission, newest_mined_blknum)
      _ = Logger.error("Submission unexpectedly failed with nonce too low: #{inspect(diagnostic)}")
      {:error, :nonce_too_low}
    end
  end

  defp prepare_diagnostic(submission, newest_mined_blknum) do
    config = Application.get_all_env(:omg_eth) |> Keyword.take([:contract_addr, :authority_addr, :txhash_contract])
    %{submission: submission, newest_mined_blknum: newest_mined_blknum, config: config}
  end
end
