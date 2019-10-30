# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.ChildChain.BlockQueue.BlockQueueCore do
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
  use OMG.Utils.LoggerExt

  alias OMG.ChildChain.BlockQueue.BlockQueueEthSync
  alias OMG.ChildChain.BlockQueue.BlockQueueInitializer
  alias OMG.ChildChain.BlockQueue.BlockQueueLogger
  alias OMG.ChildChain.BlockQueue.BlockQueueSubmitter
  alias OMG.ChildChain.BlockQueue.BlockQueueQueuer
  alias OMG.ChildChain.BlockQueue.GasPriceCalculator
  alias OMG.ChildChain.FreshBlocks

  alias OMG.Eth.Encoding
  alias OMG.Eth.EthereumHeight
  alias OMG.Eth.RootChain

  alias OMG.Block
  alias OMG.DB

  @doc ~S"""
  Initializes a block queue state to a new state or to its last known state.

  Defaults to load_init_config/0 below to load all the needed
  values from the application config and the database. A config
  with specific values can also be passed if needed.

  ## Examples

    iex> BlockQueueCore.init(
    ...> %{
    ...>   parent_height: 10,
    ...>   mined_child_block_num: 1000,
    ...>   chain_start_parent_height: 1,
    ...>   child_block_interval: 1000,
    ...>   finality_threshold: 1,
    ...>   minimal_enqueue_block_gap: 1,
    ...>   known_hashes: [{1000, "hash_1000"}],
    ...>   top_mined_hash: "hash_1000",
    ...>   last_enqueued_block_at_height: 8
    ...> })
    {:ok, %BlockQueueState{
      blocks: %{
        1000 => %BlockSubmission{hash: "hash_1000", nonce: 1, num: 1000}
      },
      mined_child_block_num: 1000,
      known_hashes: [{1000, "hash_1000"}],
      top_mined_hash: "hash_1000",
      parent_height: 10,
      child_block_interval: 1000,
      chain_start_parent_height: 1,
      minimal_enqueue_block_gap: 1,
      finality_threshold: 1,
      last_enqueued_block_at_height: 8,
      formed_child_block_num: 1000
    }}
  """
  @spec init(BlockQueueCore.init_config_t()) :: {:ok, BlockQueueState.t()} | {:error, atom}
  def init(config \\ load_init_config()) do
    config
    |> BlockQueueInitializer.init()
    |> enqueue_existing_blocks()
  end

  @doc ~S"""
  Updates the block queue state with the latest data from the rootchain,
  and returns if a new block should be formed or not.

  ## Examples

    iex> BlockQueueCore.sync_with_ethereum(
    ...> %BlockQueueState{
    ...>   blocks: %{
    ...>     1000 => %BlockSubmission{hash: "hash_1000", nonce: 1, num: 1000},
    ...>     2000 => %BlockSubmission{hash: "hash_2000", nonce: 2, num: 2000}
    ...>   },
    ...>   mined_child_block_num: 1000,
    ...>   known_hashes: [{1000, "hash_1000"}],
    ...>   top_mined_hash: "hash_1000",
    ...>   parent_height: 7,
    ...>   child_block_interval: 1000,
    ...>   chain_start_parent_height: 1,
    ...>   minimal_enqueue_block_gap: 1,
    ...>   finality_threshold: 1,
    ...>   last_enqueued_block_at_height: 7,
    ...>   formed_child_block_num: 1000
    ...> },
    ...> %{
    ...>   ethereum_height: 9,
    ...>   mined_child_block_num: 1000,
    ...>   is_empty_block: false
    ...> })
    {:do_form_block, %BlockQueueState{
      blocks: %{
        1000 => %BlockSubmission{hash: "hash_1000", nonce: 1, num: 1000},
        2000 => %BlockSubmission{hash: "hash_2000", nonce: 2, num: 2000, gas_price: nil}
      },
      mined_child_block_num: 1000,
      known_hashes: [{1000, "hash_1000"}],
      top_mined_hash: "hash_1000",
      parent_height: 9,
      child_block_interval: 1000,
      chain_start_parent_height: 1,
      minimal_enqueue_block_gap: 1,
      finality_threshold: 1,
      last_enqueued_block_at_height: 7,
      wait_for_enqueue: true,
      formed_child_block_num: 1000,
      gas_price_adj_params: %GasPriceAdjustment{
        eth_gap_without_child_blocks: 2,
        gas_price_lowering_factor: 0.9,
        gas_price_raising_factor: 2.0,
        max_gas_price: 20000000000,
        last_block_mined: {9, 1000}
      }
    }}
  """
  @spec sync_with_ethereum(BlockQueueState.t(), %{
          required(:ethereum_height) => pos_integer(),
          required(:mined_child_block_num) => pos_integer(),
          required(:is_empty_block) => bool()
        }) :: {:do_form_block, BlockQueueState.t()} | {:do_not_form_block, BlockQueueState.t()} | {:error, atom}
  def sync_with_ethereum(state, %{
        ethereum_height: ethereum_height,
        mined_child_block_num: mined_child_block_num,
        is_empty_block: is_empty_block
      }) do
    _ =
      Logger.debug("Ethereum at \#'#{inspect(ethereum_height)}', mined child at \#'#{inspect(mined_child_block_num)}'")

    state
    |> Map.put(:parent_height, ethereum_height)
    |> BlockQueueEthSync.set_mined_block_num(mined_child_block_num)
    |> GasPriceCalculator.adjust_gas_price()
    |> BlockQueueEthSync.form_block_or_skip(is_empty_block)
  end

  @doc ~S"""
  Relies on BlockQueueQueuer to add the block to the queue state if valid.

  ## Examples

      iex> BlockQueueCore.enqueue_block(
      ...> %{
      ...>   formed_child_block_num: 1000,
      ...>   child_block_interval: 1000,
      ...>   blocks: %{},
      ...>   wait_for_enqueue: nil,
      ...>   last_enqueued_block_at_height: nil
      ...> },
      ...> %Block{hash: "hash", number: 2000},
      ...> 10
      ...> )
      %{
        formed_child_block_num: 2000,
        wait_for_enqueue: false,
        last_enqueued_block_at_height: 10,
        child_block_interval: 1000,
        blocks: %{
          2000 => %BlockSubmission{hash: "hash", nonce: 2, num: 2000}
        }
      }

  """
  @spec enqueue_block(
          BlockQueueState.t(),
          %{
            required(:hash) => BlockQueue.hash(),
            required(:number) => BlockQueue.plasma_block_num()
          },
          pos_integer()
        ) :: BlockQueueState.t() | {:error, :unexpected_block_number}
  # TODO: change to block
  def enqueue_block(state, %{number: number, hash: hash} = block, parent_height) do
    _ = Logger.info("Enqueuing block num '#{inspect(number)}', hash '#{inspect(Encoding.to_hex(hash))}'")

    BlockQueueQueuer.enqueue_block(state, block, parent_height)
  end

  @doc ~S"""
  Relies on BlockQueueSubmitter to get the list of blocks to submit,
  and submit each block in sequence.

  ## Examples

      iex> BlockQueueCore.submit_blocks(
      ...> %{
      ...>   blocks: %{
      ...>     1000 => %BlockSubmission{hash: "hash_1000", nonce: 1, num: 1000},
      ...>     2000 => %BlockSubmission{hash: "hash_2000", nonce: 2, num: 2000}
      ...>   },
      ...>   formed_child_block_num: 10_000,
      ...>   gas_price_to_use: 1,
      ...>   mined_child_block_num: 6_000,
      ...>   child_block_interval: 1000
      ...> })
      :ok

  """
  @spec submit_blocks(BlockQueueState.t()) :: :ok
  def submit_blocks(%{} = state, chain \\ RootChain) do
    state
    |> BlockQueueSubmitter.get_blocks_to_submit()
    |> Enum.each(fn block ->
      BlockQueueSubmitter.submit(block, chain)
    end)
  end

  # When restarting, we don't actually know what was the state of submission process to Ethereum.
  # Some blocks might have been submitted and lost/rejected/reorged by Ethereum in the mean time.
  # To properly restart the process, we get the last blocks known to DB and split them into mined
  # blocks (might still need tracking!) and blocks not yet submitted.

  # NOTE: handles both the case when there aren't any hashes in database and there are
  @spec enqueue_existing_blocks(BlockQueueState.t()) ::
          {:ok, BlockQueueState.t()}
          | {:error, :contract_ahead_of_db | :mined_blknum_not_found_in_db | :hashes_dont_match}
  defp enqueue_existing_blocks(state) do
    case BlockQueueQueuer.enqueue_existing_blocks(state) do
      {:ok, state} ->
        {:ok, state}

      {:error, reason} = error when reason in [:mined_hash_not_found_in_db, :contract_ahead_of_db] ->
        _ =
          BlockQueueLogger.log(
            :init_error,
            known_hashes: state.known_hashes,
            parent_height: state.parent_height,
            mined_num: state.mined_child_block_num,
            stored_child_top_num: state.stored_child_top_num
          )

        error

      other ->
        other
    end
  end

  @spec get_check_interval() :: pos_integer()
  def get_check_interval do
    Application.fetch_env!(:omg_child_chain, :block_queue_eth_height_check_interval_ms)
  end

  @spec get_metrics_interval() :: pos_integer()
  def get_metrics_interval do
    Application.fetch_env!(:omg_child_chain, :metrics_collection_interval)
  end

  defp load_init_config do
    with {:ok, parent_height} <- EthereumHeight.get(),
         {:ok, mined_child_block_num} <- RootChain.get_mined_child_block(),
         {:ok, chain_start_parent_height} <- RootChain.get_root_deployment_height(),
         {:ok, child_block_interval} <- RootChain.get_child_block_interval(),
         {:ok, stored_child_top_num} <- DB.get_single_value(:child_top_block_number),
         {:ok, finality_threshold} <- Application.fetch_env(:omg_child_chain, :submission_finality_margin),
         minimal_enqueue_block_gap <- Application.fetch_env!(:omg_child_chain, :child_block_minimal_enqueue_gap),
         range =
           BlockQueueInitializer.child_block_nums_to_init_with(
             mined_child_block_num,
             stored_child_top_num,
             child_block_interval,
             finality_threshold
           ),
         {:ok, known_hashes} = DB.block_hashes(range),
         {:ok, {top_mined_hash, _}} = RootChain.get_child_chain(mined_child_block_num) do
      %{
        parent_height: parent_height,
        mined_child_block_num: mined_child_block_num,
        chain_start_parent_height: chain_start_parent_height,
        child_block_interval: child_block_interval,
        last_enqueued_block_at_height: parent_height,
        finality_threshold: finality_threshold,
        minimal_enqueue_block_gap: minimal_enqueue_block_gap,
        known_hashes: Enum.zip(range, known_hashes),
        top_mined_hash: top_mined_hash,
        stored_child_top_num: stored_child_top_num,
        range: range
      }
    else
      error ->
        # TODO: Log?
        error
    end
  end
end
