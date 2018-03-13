defmodule OmiseGO.API.BlockQueue do
  @moduledoc """
  Responsible for keeping a queue of blocks lined up nicely for submission to Eth.
  In particular responsible for picking up, where it's left off (crashed) gracefully.

  Relies on RootChain contract having reorg protection ('decimals for deposits' part).
  Relies on RootChain contract's 'authority' account not being used to send any other tx.

  TODO: react to changing gas price and submitBlock txes not being mined; needs external gas price oracle
  """

  @type hash() :: <<_::256>>

  @type eth_height() :: non_neg_integer()
  # child chain block number, as assigned by plasma contract
  @type plasma_block_num() :: pos_integer()
  @type encoded_signed_tx() :: binary()

  ### Client

  def push_block(block) do
    GenServer.call(__MODULE__.Server, {:enqueue_block, block})
  end

  def submission_mined(block_num) do
    GenServer.cast(__MODULE__.Server, {:mined_head, block_num})
  end

  def ethereum_block(height) do
    GenServer.cast(__MODULE__.Server, {:new_height, height})
  end

  def update_gas_price(price) do
    GenServer.cast(__MODULE__.Server, {:gas_price, price})
  end

  defmodule Block do
    @moduledoc false

    alias OmiseGO.API.BlockQueue, as: Lib

    @type t() :: %{
            num: Lib.plasma_block_num(),
            hash: Lib.hash(),
            nonce: non_neg_integer(),
            gas: pos_integer()
          }
    defstruct [:num, :hash, :nonce, :gas]
  end

  ### Core, purely functional, testable

  defmodule Core do
    @moduledoc """
    Maintains a queue of to-be-mined blocks. Has no side-effects or side-causes.

    (thus, it handles config values as internal variables)
    """

    alias OmiseGO.API.BlockQueue, as: Lib
    alias OmiseGO.API.BlockQueue.Block, as: Block

    defstruct [
      :blocks,
      :mined_num,
      :constructed_num,
      :parent_height,
      nonce: 0,
      priority_gas_price: 20_000_000_000,
      # config:
      child_block_interval: 1000,
      chain_start_parent_height: 1,
      submit_period: 1,
      finality_threshold: 12
    ]

    @type t() :: %__MODULE__{
            blocks: %{pos_integer() => %Block{}},
            # last mined block num
            mined_num: nil | Lib.plasma_block_num(),
            # newest constructed block num
            constructed_num: nil | Lib.plasma_block_num(),
            # current Ethereum block height
            parent_height: nil | Lib.eth_height(),
            # next nonce of account used to submit blocks
            nonce: non_neg_integer(),
            # gas price to use when (re)submitting transactions
            priority_gas_price: pos_integer(),
            # CONFIG CONSTANTS below
            # spacing of child blocks in RootChain contract
            child_block_interval: pos_integer(),
            # Ethereum height at which first block was mined
            chain_start_parent_height: pos_integer(),
            # number of Ethereum blocks per child block
            submit_period: pos_integer(),
            # depth of max reorg we take into account
            finality_threshold: pos_integer()
          }

    def new do
      %__MODULE__{blocks: Map.new()}
    end

    def new(
          nonce: nonce,
          child_block_interval: child_block_interval,
          chain_start_parent_height: child_start_parent_height,
          submit_period: submit_period,
          finality_threshold: finality_threshold
        ) do
      %__MODULE__{
        blocks: Map.new(),
        nonce: nonce,
        child_block_interval: child_block_interval,
        chain_start_parent_height: child_start_parent_height,
        submit_period: submit_period,
        finality_threshold: finality_threshold
      }
    end

    @spec enqueue_block(Core.t(), Lib.hash()) :: Core.t()
    def enqueue_block(state, hash) do
      own_height = state.constructed_num + state.child_block_interval

      block = %Block{
        num: own_height,
        nonce: state.nonce,
        hash: hash,
      }

      blocks = Map.put(state.blocks, own_height, block)
      %{state | constructed_num: own_height, blocks: blocks, nonce: state.nonce + 1}
    end

    @doc """
    Get last number of plasma block, added to queue.
    """
    def block_num(state), do: state.constructed_num

    @doc """
    Set number of plasma block mined on the parent chain.
    Since reorgs are possible, consecutive values of mined_num don't have to
    be monotonically increasing. Due to construction of contract we know it does not
    contain holes so we care only about highest number.
    """
    @spec set_mined(Core.t(), Lib.plasma_block_num()) :: Core.t()
    def set_mined(%{constructed_num: nil} = state, mined_num) do
      set_mined(%{state | constructed_num: mined_num}, mined_num)
    end

    def set_mined(state, mined_num) do
      num_threshold = mined_num - state.child_block_interval * state.finality_threshold
      young? = fn {_, block} -> block.num > num_threshold end
      blocks = state.blocks |> Enum.filter(young?) |> Map.new()
      constr = max(mined_num, state.constructed_num)

      %{state | constructed_num: constr, mined_num: mined_num, blocks: blocks}
    end

    @doc """
    Set height of Ethereum chain.
    """
    @spec set_parent_height(Core.t(), Lib.eth_height()) :: Core.t()
    def set_parent_height(state, parent_height) do
      %{state | parent_height: parent_height}
    end

    @doc """
    Change gas price for tx sent in future. This includes all re-submissions.
    Allows to react to changes in Ethereum mempool.
    """
    def set_gas_price(state, price) do
      %{state | priority_gas_price: price}
    end

    @doc """
    Query to get sequence of blocks that should be submitted to root chain.
    """
    @spec get_blocks_to_submit(Core.t()) ::
            {:ok, [Lib.encoded_signed_tx()]} | {:error, :uninitialized}
    def get_blocks_to_submit(state) do
      case ready?(state) do
        false -> {:error, :uninitialized}
        true -> {:ok, blocks_to_submit(state)}
      end
    end

    # private (core)

    defp blocks_to_submit(state) do
      %{
        blocks: blocks,
        mined_num: mined_num,
        constructed_num: constructed,
        child_block_interval: block_interval
      } = state

      range = make_range(mined_num + block_interval, constructed, block_interval)
      block_nums = rate_limiting_cutoff(range, state)

      blocks
      |> Map.split(block_nums)
      |> elem(0)
      |> Map.values()
      |> Enum.sort_by(& &1.num)
      |> Enum.map(&(Map.put(&1, :gas, state.priority_gas_price)))
    end

    # :lists.seq/3 throws, so wrapper
    defp make_range(first, last, _) when first >= last, do: []

    defp make_range(first, last, step) do
      :lists.seq(first, last, step)
    end

    defp rate_limiting_cutoff(list, state) do
      max_num = max_num(state)
      for num <- list, num <= max_num, do: num
    end

    defp max_num(state) do
      (1 + trunc((state.parent_height - state.chain_start_parent_height) / state.submit_period)) *
        state.child_block_interval
    end

    @spec ready?(Core.t()) :: boolean
    defp ready?(state) do
      state.mined_num != nil and state.constructed_num != nil and state.parent_height != nil
    end
  end

  ### Server, part of imperative shell

  defmodule Server do
    @moduledoc """
    Stores core's state, handles timing of calls to root chain.
    Is driven by block height and mined tx data delivered by local geth node and new blocks
    formed by server. It may resubmit tx multiple times, until it is mined.
    """

    use GenServer

    def init(:ok) do
      {:ok, Core.new()}
    end

    def handle_call({:enqueue_block, block}, from, state) do
      GenServer.reply(from, :ok)
      state1 = Core.enqueue_block(state, block)
      _ = submit_blocks(state1)
      {:noreply, state1}
    end

    def handle_cast({:mined_head, mined_num}, state) do
      state1 = Core.set_mined(state, mined_num)
      _ = submit_blocks(state1)
      {:noreply, state1}
    end

    def handle_cast({:new_height, height}, state) do
      state1 = Core.set_parent_height(state, height)
      _ = submit_blocks(state1)
      {:noreply, state1}
    end

    def handle_cast({:gas_price, price}, state) do
      state1 = Core.set_gas_price(state, price)
      _ = submit_blocks(state1)
      {:noreply, state1}
    end

    # private (server)

    @spec submit_blocks(Core.t()) :: :ok
    defp submit_blocks(state) do
      state
      |> Core.get_blocks_to_submit()
      |> Enum.each(&Eth.submit_block(&1.nonce, &1.hash, &1.gas))
    end
  end
end
