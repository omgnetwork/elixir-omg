defmodule OmiseGO.API.BlockQueue do
  @moduledoc """
  Responsible for keeping a queue of blocks lined up nicely for submission to Eth.
  In particular responsible for picking up, where it's left off (crashed) gracefully.

  Relies on RootChain contract having reorg protection ('decimals for deposits' part).
  Relies on RootChain contract's 'authority' account not being used to send any other tx.

  TODO: react to changing gas price and submitBlock txes not being mined; needs external gas price oracle
  """

  alias OmiseGO.API.BlockQueue.Core, as: Core

  @type hash() :: <<_::256>>

  @type eth_height() :: non_neg_integer()
  # child chain block number, as assigned by plasma contract
  @type plasma_block_num() :: pos_integer()
  @type encoded_signed_tx() :: binary()

  ### Client

  @spec update_gas_price(price :: pos_integer()) :: :ok
  def update_gas_price(price) do
    GenServer.cast(__MODULE__.Server, {:update_gas_price, price})
  end

  defmodule Server do
    @moduledoc """
    Stores core's state, handles timing of calls to root chain.
    Is driven by block height and mined tx data delivered by local geth node and new blocks
    formed by server. It may resubmit tx multiple times, until it is mined.
    """

    use GenServer

    def init(:ok) do
      finality = 12
      # NOTE: something throws, suspect: ethereumex
      try do
        with {:ok, parent_height} <- Eth.get_ethereum_height(),
             {:ok, mined_num} <- Eth.get_current_child_block(),
             {:ok, parent_start} <- Eth.get_root_deployment_height(),
             {:ok, known_hashes} <- OmiseGO.FreshBlocks.get_top_blocks(finality),
             {:ok, top_mined_hash} = Eth.get_child_block_root(mined_num) do
          {:ok, state} = Core.new(
            mined_num: mined_num,
            known_hashes: known_hashes,
            top_mined_hash: top_mined_hash,
            parent_height: parent_height,
            child_block_interval: 1000,
            chain_start_parent_height: parent_start,
            submit_period: 1,
            finality_threshold: finality
          )
          {:ok, _} = :timer.send_interval(1000, self(), :check_mined_child_head)
          {:ok, _} = :timer.send_interval(1000, self(), :check_ethereum_height)
          {:ok, state}
        end
      catch
        error -> {:stop, {:unable_to_init_block_queue, error}}
      end
    end

    def handle_cast({:update_gas_price, price}, state) do
      state1 = Core.set_gas_price(state, price)
      # resubmit pending tx with updated gas price; allowing them to be mined if price is higher
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
           state1 <- Core.set_ethereum_height(state, height),
           true <- create_block(state1),
           {:ok, to_form} <- Core.get_formed_block_num(state, +1),
           {:ok, following} <- Core.get_formed_block_num(state, +2),
           {:ok, block_hash} <- OmiseGO.API.State.form_block(to_form, following),
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
