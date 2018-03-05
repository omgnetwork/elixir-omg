defmodule OmiseGO.BlockQueue do
  @moduledoc """
  Responsible for keeping a queue of blocks lined up nicely for submission to Eth.
  In particular responsible for picking up, where it's left off (crashed) gracefully
  """

  @finality_threshold 100 # don't care about blocks older than that

  ### Client

  def push_block(block) do
    GenServer.call(__MODULE__.Server, {:enqueue_block, block})
  end

  def status() do
    GenServer.call(__MODULE__.Server, :status)
  end

  def submission_mined(height)

  ### Server, part of imperative shell

  defmodule Server do
    ### Stores core's state, handles timing of calls to root chain.
    ### Is driven by block height, pending and mined tx data delivered by local
    ###   geth node and new blocks formed by server.

    use GenServer

    def init(:ok) do
      Core.from_db()
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
    defstruct [:blocks, :last_submitted_height, :last_mined_submission, :last_formed_height,
               :last_parent_height]

    def from_db(blocks) do
      %__MODULE__{blocks: Map.new(blocks),
                  last_submitted_height: nil,
                  last_mined_height: nil,
                  last_formed_height: nil,
                  last_parent_height: nil}
    end

    @spec ready?(state) :: boolean
    defp ready?(state) do
      state.last_submitted_height != nil and
      state.last_mined_height != nil and
      state.last_formed_height != nil and
      state.last_parent_height != nil
    end

    @spec enqueue_block(state, block) :: state
    def enqueue_block(state, block) do
      %{state | last_formed_height: state.last_formed_height + 1}
    end

    @doc """
    Height of last plasma block mined on the parent chain.
    Since reorgs are possible, consecutive values of mined_height don't have to
    be monotonically increasing.
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
    Height of parent chain.
    """
    @spec set_parent_height(state, pos_integer) :: state
    def set_parent_height(state, new_height) do
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
