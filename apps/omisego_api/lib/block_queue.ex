defmodule OmiseGO.API.BlockQueue do
  @moduledoc """
  Responsible for keeping a queue of blocks lined up nicely for submission to Eth.
  In particular responsible for picking up, where it's left off (crashed) gracefully.

  Relies on RootChain contract having reorg protection ('decimals for deposits' part).
  Relies on RootChain contract's 'authority' account not being used to send any other tx.

  TODO: re-submission of rejected tx with higher gas price; needs external gas price oracle
  """

  @finality_threshold 60 # don't care about blocks older than that

  @child_block_interval 1000 # TODO: fetch from contract

  # child chain block number, as assigned by plasma contract
  @typep eth_height :: non_neg_integer()
  @typep plasma_block_num() :: pos_integer()

  ### Client

  def push_block(block) do
    GenServer.call(__MODULE__.Server, {:enqueue_block, block})
  end

  def status() do
    GenServer.call(__MODULE__.Server, :status)
  end

  def submission_mined(_height), do: :not_implemented

  ### Server, part of imperative shell

  defmodule Server do
    ### Stores core's state, handles timing of calls to root chain.
    ### Is driven by block height, pending and mined tx data delivered by local
    ###   geth node and new blocks formed by server.

    use GenServer

    def init(:ok) do
      Core.new()
    end

    def handle_call({:enqueue_block, block}, from, state) do
      GenServer.reply(from, :ok)
      state1 = Core.enqueue_block(state, block)
      :ok = submit_blocks(state1)
      {:noreply, state1}
    end

    def handle_call(:status, from, state) do
      {:reply, Core.status(state), state}
    end

    def handle_info({:new_height, height}, state) do
      state1 = Core.set_parent_height(state, height)
      :ok = submit_blocks(state1)
      {:noreply, state1}
    end

    def handle_info({:known_txs, tx_list}, state) do
      state1 = Core.set_submitted(state, tx_list)
      :ok = submit_blocks(state1)
      {:noreply, state1}
    end

    def handle_info({:known_roots, root_hash_list}, state) do
      state1 = Core.set_mined(state, root_hash_list)
      :ok = submit_blocks(state1)
      {:noreply, state1}
    end

    @spec submit_blocks(state) :: :ok
    defp submit_blocks(state) do
      state
      |> Core.get_blocks_to_submit()
      |> Enum.each(&(Eth.Contract.submit_block(&1)))
    end
  end

  ### Core, purely functional, testable

  defmodule Core do
    @moduledoc """
    Handles maintaining the queue of to-be-mined blocks. Has no side-effects or side-causes.
    """
    defstruct [:blocks :: %{pos_integer() => child_block()},
               :submitted_num :: nil | plasma_block_num(),
               :mined_num :: nil | plasma_block_num(),
               :constructed_num :: nil | plasma_block_num(),
               :parent_height :: nil | eth_height(),
               :acc_nonce :: nil | non_neg_integer(),
              ]

    defmodule Block {
      @type t() :: %{
        num: plasma_block_num(),
        hash: binary(),
        tx: binary(),
        included_into: nil | eth_height()
      }
      defstruct [:num, :hash, :tx, :included_into = nil]
    }

    def new(), do: new([nonce: 1])

    def new([nonce: initial_nonce]) do
      %__MODULE__{blocks: Map.new(),
                  submitted_num: nil,
                  mined_num: nil,
                  constructed_num: 0,
                  parent_height: nil,
                  acc_nonce: initial_nonce,
      }
    end

    @spec ready?(state) :: boolean
    defp ready?(state) do
      state.submitted_num != nil and
      state.mined_num != nil and
      state.constructed_num != nil and
      state.parent_height != nil and
      state.acc_nonce != nil
    end

    defp finalized_height(state), do: state.parent_height - @finality_threshold

    @spec enqueue_block(state, block) :: state
    def enqueue_block(state, block) do
      own_height = bump(state.constructed_num, @child_block_interval)
      tx = OmiseGo.Eth.submit_block_tx(nonce, block)
      block = %Block{num: own_height, hash: block, tx: tx}
      blocks = Map.insert(state.blocks, own_height, block)
      %{state | constructed_height: own_height, blocks: blocks}
    end

    defp bump(nil, increment), do: increment
    defp bump(value, increment), do: value + increment

    @doc """
    Height of last plasma block mined on the parent chain.
    Since reorgs are possible, consecutive values of mined_height don't have to
    be monotonically increasing. GC of old blocks is done here.
    """
    @spec set_mined(state, pos_integer()) :: state
    def set_mined(state, mined_height) do
      state
    end

    @doc """
    Heights of block that are submitted but not yet mined. State reported by root chain node.

    Since tx'es might be dropped by the network, sequence may contain holes.
    """
    @spec set_submitted(state, [pos_integer()]) :: state
    def set_submitted(state, submitted_heights) do
      state
    end

    @doc """
    Query to get sequence of blocks that should be submitted to root chain for particular root chain height.
    """
    @spec get_blocks_to_submit(state, pos_integer()) :: submit_list
    def get_blocks_to_submit(state, ethereum_height) do
      case ready?(state) do
        false -> []
        true -> []
      end
    end

    @doc """
    Query to get current state of submission queue.
    """
    @spec status(state) :: {:ok, state}
    def status(state) do
      state
    end

  end
end
