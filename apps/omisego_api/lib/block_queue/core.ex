defmodule OmiseGO.API.BlockQueue.Core do
  @moduledoc """
  Maintains a queue of to-be-mined blocks. Has no side-effects or side-causes.

  Note that first nonce (zero) of authority account is used to deploy RootChain.
  Every next nonce is used to submit operator blocks.

  (thus, it handles config values as internal variables)
  """

  alias OmiseGO.Eth.BlockSubmission
  alias OmiseGO.API.BlockQueue, as: BlockQueue
  alias OmiseGO.API.BlockQueue.Core
  alias OmiseGO.API.BlockQueue.GasPriceAdjustmentStrategyParams, as: GasPriceParams

  use OmiseGO.API.LoggerExt

  @zero_bytes32 <<0::size(256)>>

  defstruct [
    :blocks,
    :parent_height,
    formed_child_block_num: 0,
    wait_for_enqueue: false,
    gas_price_to_use: 20_000_000_000,
    mined_child_block_num: 0,
    # config:
    child_block_interval: nil,
    chain_start_parent_height: nil,
    submit_period: 1,
    finality_threshold: 12,
    gas_price_adj_params: %GasPriceParams{}
  ]

  @type t() :: %__MODULE__{
          blocks: %{pos_integer() => %BlockSubmission{}},
          # last mined block num
          mined_child_block_num: BlockQueue.plasma_block_num(),
          # newest formed block num
          formed_child_block_num: BlockQueue.plasma_block_num(),
          # current Ethereum block height
          parent_height: nil | BlockQueue.eth_height(),
          # whether we're pending an enqueue signal with a new block
          wait_for_enqueue: boolean(),
          # gas price to use when (re)submitting transactions
          gas_price_to_use: pos_integer(),
          # CONFIG CONSTANTS below
          # spacing of child blocks in RootChain contract, being the amount of deposit decimals per child block
          child_block_interval: pos_integer(),
          # Ethereum height at which first block was mined
          chain_start_parent_height: pos_integer(),
          # number of Ethereum blocks per child block
          submit_period: pos_integer(),
          # depth of max reorg we take into account
          finality_threshold: pos_integer(),
          # the gas price adjustment strategy parameters
          gas_price_adj_params: GasPriceParams.t()
        }

  def new do
    {:ok, %__MODULE__{blocks: Map.new()}}
  end

  @spec new(keyword) :: {:ok, Core.t()} | {:error, :mined_hash_not_found_in_db} | {:error, :contract_ahead_of_db}
  def new(
        mined_child_block_num: mined_child_block_num,
        known_hashes: known_hashes,
        top_mined_hash: top_mined_hash,
        parent_height: parent_height,
        child_block_interval: child_block_interval,
        chain_start_parent_height: child_start_parent_height,
        submit_period: submit_period,
        finality_threshold: finality_threshold
      ) do
    state = %__MODULE__{
      blocks: Map.new(),
      mined_child_block_num: mined_child_block_num,
      parent_height: parent_height,
      child_block_interval: child_block_interval,
      chain_start_parent_height: child_start_parent_height,
      submit_period: submit_period,
      finality_threshold: finality_threshold,
      gas_price_adj_params: %GasPriceParams{}
    }

    enqueue_existing_blocks(state, top_mined_hash, known_hashes)
  end

  @spec enqueue_block(Core.t(), BlockQueue.hash(), BlockQueue.plasma_block_num()) ::
          Core.t() | {:error, :unexpected_block_number}
  def enqueue_block(state, hash, expected_block_number) do
    own_height = state.formed_child_block_num + state.child_block_interval

    with :ok <- validate_block_number(expected_block_number, own_height) do
      enqueue_block(state, hash)
    end
  end

  defp validate_block_number(block_number, own_height) when block_number == own_height, do: :ok
  defp validate_block_number(_, _), do: {:error, :unexpected_block_number}

  defp enqueue_block(state, hash) do
    own_height = state.formed_child_block_num + state.child_block_interval

    block = %BlockSubmission{
      num: own_height,
      nonce: calc_nonce(own_height, state.child_block_interval),
      hash: hash
    }

    blocks = Map.put(state.blocks, own_height, block)
    %{state | formed_child_block_num: own_height, blocks: blocks, wait_for_enqueue: false}
  end

  @doc """
  Set number of plasma block mined on the parent chain.

  Since reorgs are possible, consecutive values of mined_child_block_num don't have to be
  monotonically increasing. Due to construction of contract we know it does not
  contain holes so we care only about the highest number.
  """
  @spec set_mined(Core.t(), BlockQueue.plasma_block_num()) :: Core.t()
  def set_mined(state, mined_child_block_num) do
    num_threshold = mined_child_block_num - state.child_block_interval * state.finality_threshold
    young? = fn {_, block} -> block.num > num_threshold end
    blocks = state.blocks |> Enum.filter(young?) |> Map.new()
    top_known_block = max(mined_child_block_num, state.formed_child_block_num)

    %{state | formed_child_block_num: top_known_block, mined_child_block_num: mined_child_block_num, blocks: blocks}
  end

  @doc """
  Set height of Ethereum chain.
  """
  @spec set_ethereum_height(Core.t(), BlockQueue.eth_height()) ::
          {:do_form_block, Core.t(), pos_integer, pos_integer} | {:dont_form_block, Core.t()}
  def set_ethereum_height(state, parent_height) do
    new_state = %{state | parent_height: parent_height}
    new_state = adjust_gas_price(new_state)

    if should_form_block?(new_state) do
      {:do_form_block, %{new_state | wait_for_enqueue: true}}
    else
      {:dont_form_block, new_state}
    end
  end

  # Updates gas price to use basing on :calculate_gas_price function, updates current parent height
  # and last mined child block number in the state which used by gas price calculations
  @spec adjust_gas_price(Core.t()) :: Core.t()
  defp adjust_gas_price(%Core{parent_height: nil} = state), do: state

  defp adjust_gas_price(%Core{gas_price_adj_params: %GasPriceParams{last_block_mined: nil} = gas_params} = state) do
    # initializes last block mined
    %{state | gas_price_adj_params: GasPriceParams.with(gas_params, state.parent_height, state.mined_child_block_num)}
  end

  defp adjust_gas_price(
         %Core{
           parent_height: parent_height,
           gas_price_adj_params: %GasPriceParams{last_block_mined: {last_parent_height, _mined_block_num}}
         } = state
       )
       when parent_height == last_parent_height,
       do: state

  defp adjust_gas_price(%Core{} = state) do
    new_gas_price = calculate_gas_price(state)
    _ = Logger.debug(fn -> "using new gas price '#{new_gas_price}'" end)

    state
    |> set_gas_price(new_gas_price)
    |> update_last_checked_mined_block_num()
  end

  # Calculates the gas price basing on simple strategy to raise the gas price by gas_price_raising_factor
  # when gap of mined parent blocks is growing and droping the price by gas_price_lowering_factor otherwise
  @spec calculate_gas_price(Core.t()) :: pos_integer()
  defp calculate_gas_price(%Core{
         formed_child_block_num: formed_child_block_num,
         mined_child_block_num: mined_child_block_num,
         gas_price_to_use: gas_price_to_use,
         parent_height: parent_height,
         gas_price_adj_params: %GasPriceParams{
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
           gas_price_adj_params: %GasPriceParams{
             last_block_mined: {_lastechecked_parent_height, lastchecked_mined_block_num}
           }
         } = state
       ) do
    if lastchecked_mined_block_num < mined_child_block_num do
      %Core{
        state
        | gas_price_adj_params: GasPriceParams.with(state.gas_price_adj_params, parent_height, mined_child_block_num)
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

  Picks for submission the child blocks that haven't yet been seen mined on Ethereum
  """
  @spec get_blocks_to_submit(Core.t()) :: [BlockQueue.encoded_signed_tx()]
  def get_blocks_to_submit(state) do
    %{
      blocks: blocks,
      mined_child_block_num: mined_child_block_num,
      formed_child_block_num: formed,
      child_block_interval: block_interval
    } = state

    first_blknum = mined_child_block_num + block_interval
    block_nums = make_range(first_blknum, formed, block_interval)

    _ = Logger.debug(fn -> "preparing blocks #{first_blknum}..#{formed} for submission" end)

    blocks
    |> Map.split(block_nums)
    |> elem(0)
    |> Map.values()
    |> Enum.sort_by(& &1.num)
    |> Enum.map(&Map.put(&1, :gas_price, state.gas_price_to_use))
  end

  # generates an enumberable of block numbers since genesis till a particular block number (inclusive
  @spec child_block_nums_to_init_with(non_neg_integer) :: list
  def child_block_nums_to_init_with(until_child_block_num) do
    # equivalent of range(BlockQueue.child_block_interval(),
    #                     until_child_block_num + BlockQueue.child_block_interval(),
    #                     BlockQueue.child_block_interval()
    #                     )
    interval = BlockQueue.child_block_interval()
    make_range(interval, until_child_block_num, interval)
  end

  # Check if new child block should be formed basing on blocks formed so far and
  # age of RootChain contract in ethereum blocks
  @spec should_form_block?(Core.t()) :: true | false
  defp should_form_block?(state) do
    due_child_block_num(state) > state.formed_child_block_num && !state.wait_for_enqueue
  end

  # private (core)

  defp calc_nonce(height, interval) do
    trunc(height / interval)
  end

  defp due_child_block_num(state) do
    root_chain_age_in_ethereum_blocks = state.parent_height - state.chain_start_parent_height
    child_chain_blocks_due = trunc(root_chain_age_in_ethereum_blocks / state.submit_period)
    child_chain_blocks_due * state.child_block_interval
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

      _ =
        Logger.info(fn ->
          {first, _} = mined_blocks |> hd
          last = state.mined_child_block_num

          "Block queue loaded with #{first}..#{last} already mined and #{Enum.count(fresh_blocks)} fresh blocks enqueued"
        end)

      {:ok, Enum.reduce(fresh_blocks, state, fn hash, acc -> enqueue_block(acc, hash) end)}
    end
  end

  # splits into ones that are before top_mined_hash and those after
  # mined are zipped with their numbers to submit
  defp split_existing_blocks(%__MODULE__{mined_child_block_num: blknum}, blknums_and_hashes) do
    index = Enum.find_index(blknums_and_hashes, &(elem(&1, 0) == blknum))

    {mined, fresh} = Enum.split(blknums_and_hashes, index + 1)
    fresh_hashes = Enum.map(fresh, &elem(&1, 1))

    {mined, fresh_hashes}
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
