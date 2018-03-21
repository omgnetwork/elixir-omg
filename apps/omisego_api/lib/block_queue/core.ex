defmodule OmiseGO.API.BlockQueue.Core do
  @moduledoc """
  Maintains a queue of to-be-mined blocks. Has no side-effects or side-causes.

  (thus, it handles config values as internal variables)
  """

  defmodule BlockSubmission do
    @moduledoc false

    alias OmiseGO.API.BlockQueue, as: BlockQueue

    @type t() :: %{
      num: BlockQueue.plasma_block_num(),
      hash: BlockQueue.hash(),
      nonce: non_neg_integer(),
      gas: pos_integer()
    }
    defstruct [:num, :hash, :nonce, :gas]
  end

  alias OmiseGO.API.BlockQueue, as: BlockQueue

  defstruct [
    :blocks,
    :mined_child_block_num,
    :formed_child_block_num,
    :parent_height,
    gas_price_to_use: 20_000_000_000,
    # config:
    child_block_interval: 1000,
    chain_start_parent_height: 1,
    submit_period: 1,
    finality_threshold: 12
  ]

  @type t() :: %__MODULE__{
          blocks: %{pos_integer() => %BlockSubmission{}},
          # last mined block num
          mined_child_block_num: nil | BlockQueue.plasma_block_num(),
          # newest formed block num
          formed_child_block_num: nil | BlockQueue.plasma_block_num(),
          # current Ethereum block height
          parent_height: nil | BlockQueue.eth_height(),
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
          finality_threshold: pos_integer()
        }

  def new do
    {:ok, %__MODULE__{blocks: Map.new()}}
  end

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
      finality_threshold: finality_threshold
    }

    enqueue_existing_blocks(state, top_mined_hash, known_hashes)
  end

  @spec enqueue_block(Core.t(), BlockQueue.hash()) :: Core.t()
  def enqueue_block(state, hash) do
    own_height = state.formed_child_block_num + state.child_block_interval

    block = %BlockSubmission{
      num: own_height,
      nonce: calc_nonce(own_height, state.child_block_interval),
      hash: hash
    }

    blocks = Map.put(state.blocks, own_height, block)
    %{state | formed_child_block_num: own_height, blocks: blocks}
  end

  @doc """
  Get current block number (`block_num(state, 0)`), next block number (`block_num(state, 1)`), etc
  """
  def get_formed_block_num(state, delta) do
    {:ok, state.formed_child_block_num + (delta * state.child_block_interval)}
  end

  @doc """
  Set number of plasma block mined on the parent chain.

  Since reorgs are possible, consecutive values of mined_child_block_num don't have to be
  monotonically increasing. Due to construction of contract we know it does not
  contain holes so we care only about the highest number.
  """
  @spec set_mined(Core.t(), BlockQueue.plasma_block_num()) :: Core.t()
  def set_mined(%{formed_child_block_num: nil} = state, mined_child_block_num) do
    set_mined(%{state | formed_child_block_num: mined_child_block_num}, mined_child_block_num)
  end

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
  @spec set_ethereum_height(Core.t(), BlockQueue.eth_height()) :: Core.t()
  def set_ethereum_height(state, parent_height) do
    %{state | parent_height: parent_height}
  end

  @doc """
  Change gas price for tx sent in future. This includes all re-submissions.

  Allows to react to changes of Ethereum mempool utilization.
  """
  def set_gas_price(state, price) do
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

    block_nums = make_range(mined_child_block_num + block_interval, formed, block_interval)

    blocks
    |> Map.split(block_nums)
    |> elem(0)
    |> Map.values()
    |> Enum.sort_by(& &1.num)
    |> Enum.map(&Map.put(&1, :gas, state.gas_price_to_use))
  end

  @doc """
  Check if new child block should be formed basing on blocks formed so far and
  age of RootChain contract in ethereum blocks.
  """
  @spec create_block?(Core.t()) :: true | false
  def create_block?(state) do
    max_num_since_genesis(state) > state.formed_child_block_num
  end

  # private (core)

  defp calc_nonce(height, interval) do
    trunc(height / interval)
  end

  defp max_num_since_genesis(state) do
    root_chain_age_in_ethereum_blocks = state.parent_height - state.chain_start_parent_height
    child_chain_blocks_created = trunc(root_chain_age_in_ethereum_blocks / state.submit_period)
    # add one because child block numbering starts from 1 * state.child_block_interval
    (1 + child_chain_blocks_created) * state.child_block_interval
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
  @spec enqueue_existing_blocks(Core.t(), BlockQueue.hash(), [BlockQueue.hash()]) ::
          {:ok, Core.t()} | false
  defp enqueue_existing_blocks(state, top_mined_hash, hashes) do
    with true <- Enum.member?(hashes, top_mined_hash) do
      index = Enum.find_index(hashes, &(&1 == top_mined_hash))
      {mined, fresh} = Enum.split(hashes, index + 1)
      bottom_mined = state.mined_child_block_num - state.child_block_interval * (length(mined) - 1)
      nums = make_range(bottom_mined, state.mined_child_block_num, state.child_block_interval)

      mined_blocks =
        for {num, hash} <- Enum.zip(nums, mined) do
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
        | formed_child_block_num: state.mined_child_block_num + state.child_block_interval,
          blocks: mined_blocks
      }

      {:ok, Enum.reduce(fresh, state, fn hash, acc -> enqueue_block(acc, hash) end)}
    end
  end
end
