defmodule OmiseGO.API.BlockQueue do
  @moduledoc """
  Responsible for keeping a queue of blocks lined up nicely for submission to Eth.
  In particular responsible for picking up, where it's left off (crashed) gracefully.

  Relies on RootChain contract having reorg protection ('decimals for deposits' part).
  Relies on RootChain contract's 'authority' account not being used to send any other tx.

  TODO: if restarted, actively load last state
  TODO: react to changing gas price and submitBlock txes not being mined; needs external gas price oracle
  """

  @type hash() :: <<_::256>>

  @type eth_height() :: non_neg_integer()
  # child chain block number, as assigned by plasma contract
  @type plasma_block_num() :: pos_integer()
  @type encoded_signed_tx() :: binary()

  ### Client

  @spec mined_child_head(block_num :: pos_integer()) :: :ok
  def mined_child_head(block_num) do
    GenServer.cast(__MODULE__.Server, {:mined_child_head, block_num})
  end

  @spec new_ethereum_height(height :: pos_integer()) :: :ok
  def new_ethereum_height(height) do
    GenServer.cast(__MODULE__.Server, {:new_ethereum_height, height})
  end

  @spec get_child_block_number :: {:ok, nil | pos_integer()}
  def get_child_block_number do
    GenServer.call(__MODULE__.Server, :get_child_block_number)
  end

  @spec update_gas_price(price :: pos_integer()) :: :ok
  def update_gas_price(price) do
    GenServer.cast(__MODULE__.Server, {:update_gas_price, price})
  end

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

  defmodule Core do
    @moduledoc """
    Maintains a queue of to-be-mined blocks. Has no side-effects or side-causes.

    (thus, it handles config values as internal variables)
    """

    alias OmiseGO.API.BlockQueue, as: BlockQueue
    alias OmiseGO.API.BlockQueue.BlockSubmission, as: BlockSubmission

    defstruct [
      :blocks,
      :mined_num,
      :constructed_num,
      :parent_height,
      priority_gas_price: 20_000_000_000,
      # config:
      child_block_interval: 1000,
      chain_start_parent_height: 1,
      submit_period: 1,
      finality_threshold: 12
    ]

    @type t() :: %__MODULE__{
            blocks: %{pos_integer() => %BlockSubmission{}},
            # last mined block num
            mined_num: nil | BlockQueue.plasma_block_num(),
            # newest constructed block num
            constructed_num: nil | BlockQueue.plasma_block_num(),
            # current Ethereum block height
            parent_height: nil | BlockQueue.eth_height(),
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
          child_block_interval: child_block_interval,
          chain_start_parent_height: child_start_parent_height,
          submit_period: submit_period,
          finality_threshold: finality_threshold
        ) do
      %__MODULE__{
        blocks: Map.new(),
        child_block_interval: child_block_interval,
        chain_start_parent_height: child_start_parent_height,
        submit_period: submit_period,
        finality_threshold: finality_threshold
      }
    end

    @spec enqueue_block(Core.t(), BlockQueue.hash()) :: Core.t()
    def enqueue_block(state, hash) do
      own_height = state.constructed_num + state.child_block_interval
      nonce = trunc(own_height / state.child_block_interval)

      block = %BlockSubmission{
        num: own_height,
        nonce: nonce,
        hash: hash
      }

      blocks = Map.put(state.blocks, own_height, block)
      %{state | constructed_num: own_height, blocks: blocks}
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
    @spec set_mined(Core.t(), BlockQueue.plasma_block_num()) :: Core.t()
    def set_mined(%{constructed_num: nil} = state, mined_num) do
      set_mined(%{state | constructed_num: mined_num}, mined_num)
    end

    def set_mined(state, mined_num) do
      num_threshold = mined_num - state.child_block_interval * state.finality_threshold
      young? = fn {_, block} -> block.num > num_threshold end
      blocks = state.blocks |> Enum.filter(young?) |> Map.new()
      top_known_block = max(mined_num, state.constructed_num)

      %{state | constructed_num: top_known_block, mined_num: mined_num, blocks: blocks}
    end

    @doc """
    Set height of Ethereum chain.
    """
    @spec set_parent_height(Core.t(), BlockQueue.eth_height()) :: Core.t()
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
    Check if new block should be formed.
    """
    @spec create_block?(Core.t()) :: true | false
    def create_block?(state) do
      max_num(state) == state.constructed_num
    end

    @doc """
    Query to get sequence of blocks that should be submitted to root chain.
    """
    @spec get_blocks_to_submit(Core.t()) :: [BlockQueue.encoded_signed_tx()]
    def get_blocks_to_submit(state) do
      %{
        blocks: blocks,
        mined_num: mined_num,
        constructed_num: constructed,
        child_block_interval: block_interval
      } = state

      block_nums = make_range(mined_num + block_interval, constructed, block_interval)

      blocks
      |> Map.split(block_nums)
      |> elem(0)
      |> Map.values()
      |> Enum.sort_by(& &1.num)
      |> Enum.map(&Map.put(&1, :gas, state.priority_gas_price))
    end

    # private (core)

    # :lists.seq/3 throws, so wrapper
    defp make_range(first, last, _) when first >= last, do: []

    defp make_range(first, last, step) do
      :lists.seq(first, last, step)
    end

    defp max_num(state) do
      (1 + trunc((state.parent_height - state.chain_start_parent_height) / state.submit_period)) *
        state.child_block_interval
    end
  end

  defmodule Server do
    @moduledoc """
    Stores core's state, handles timing of calls to root chain.
    Is driven by block height and mined tx data delivered by local geth node and new blocks
    formed by server. It may resubmit tx multiple times, until it is mined.
    """

    use GenServer

    def init(:ok) do
      with {:ok, parent_height} <- Eth.get_ethereum_height(),
           {:ok, mined_num} <- Eth.get_current_child_block() do
        {:ok, _} = :timer.send_interval(1000, self(), :check_mined_child_head)
        {:ok, _} = :timer.send_interval(1000, self(), :check_ethereum_height)
        state =
          Core.new()
          |> Core.set_mined(mined_num)
          |> Core.set_parent_height(parent_height)
        {:ok, state}
      end
    end

    def handle_call(:get_child_block_number, _from, state) do
      {:reply, {:ok, state.constructed_num}, state}
    end

    def handle_cast({:update_gas_price, price}, state) do
      state1 = Core.set_gas_price(state, price)
      # resubmit pending tx with new gas; allowing them to be mined if price is higher
      submit_blocks(state1)
      {:noreply, state1}
    end

    def handle_info(:check_mined_child_head, state) do
      {:ok, mined_num} = Eth.get_current_child_block()
      state1 = Core.set_mined(state, mined_num)
      submit_blocks(state1)
      {:noreply, state1}
    end

    def handle_info(:check_ethereum_height, state) do
      with {:ok, height} <- Eth.get_ethereum_height(),
           state1 <- Core.set_parent_height(state, height),
           true <- create_block(state1),
           {:ok, block_hash} <- OmiseGO.API.State.form_block(),
           state2 <- Core.enqueue_block(state1, block_hash) do
        submit_blocks(state2)
        {:noreply, state2}
      end
    end

    # private (server)

    @spec create_block(Core.t()) :: true | {:noreply, Core.t()}
    def create_block(state) do
      case Core.create_block?(state) do
        true -> true
        false -> {:noreply, state}
      end
    end

    @spec submit_blocks(Core.t()) :: :ok
    defp submit_blocks(state) do
      state
      |> Core.get_blocks_to_submit()
      |> Enum.each(&Eth.submit_block(&1.nonce, &1.hash, &1.gas))
    end
  end
end
