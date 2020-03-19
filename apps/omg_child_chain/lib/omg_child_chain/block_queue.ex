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

defmodule OMG.ChildChain.BlockQueue do
  @moduledoc """
  Manages the process of submitting new blocks to the root chain contract.

  On startup uses information persisted in `OMG.DB` and the root chain contract to recover the status of the
  submissions.

  Tracks the current Ethereum height as well as the mined child chain block submissions to date. Based on this,
  `OMG.ChildChain.BlockQueue.Core` triggers the forming of a new child chain block (by `OMG.State.form_block`).

  Listens to newly formed blocks to enqueue arriving via an `OMG.Bus` subscription, hands them off to
  `OMG.ChildChain.BlockQueue.Core` to track and submits them with appropriate gas price.

  Uses `OMG.ChildChain.BlockQueue.Core` to determine whether to resubmit blocks not yet mined on the root chain with
  a higher gas price.

  Receives responses from the Ethereum RPC (or another submitting agent) and uses `OMG.ChildChain.BlockQueue.Core` to
  determine what they mean to the process of submitting - see `OMG.ChildChain.BlockQueue.Core.process_submit_result/3`
  for details.

  See `OMG.ChildChain.BlockQueue.Core` for the implementation of the business logic for the block queue.

  Handles timing of calls to root chain.
    Driven by block height and mined transaction data delivered by local geth node and new blocks
    formed by server. Resubmits transaction until it is mined.
  """

  use OMG.Utils.LoggerExt

  alias OMG.Block
  alias OMG.ChildChain.BlockQueue.Core
  alias OMG.ChildChain.BlockQueue.Core.BlockSubmission
  alias OMG.ChildChain.BlockQueue.GasAnalyzer
  alias OMG.ChildChain.FreshBlocks
  alias OMG.Eth
  alias OMG.Eth.Encoding
  alias OMG.Eth.EthereumHeight

  @type eth_height() :: non_neg_integer()
  @type hash() :: BlockSubmission.hash()
  @type plasma_block_num() :: BlockSubmission.plasma_block_num()
  # child chain block number, as assigned by plasma contract
  @type encoded_signed_tx() :: binary()
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc """
  Initializes the GenServer state, most work done in `handle_continue/2`.
  """
  def init(args) do
    {:ok, args, {:continue, :setup}}
  end

  @doc """
  Reads the status of submitting from `OMG.DB` (the blocks persisted there). Iniitializes the state based on this and
  configuration.

  In particular it re-enqueues any blocks whose submissions have not yet been seen mined.
  """
  def handle_continue(:setup, args) do
    _ = Logger.info("Starting #{__MODULE__} service.")
    :ok = Eth.node_ready()

    {:ok, parent_start} = Eth.RootChain.get_root_deployment_height()

    {:ok, parent_height} = EthereumHeight.get()
    {:ok, mined_num} = Eth.RootChain.get_mined_child_block()
    {:ok, child_block_interval} = Eth.RootChain.get_child_block_interval()
    {:ok, stored_child_top_num} = OMG.DB.get_single_value(:child_top_block_number)
    finality_threshold = Keyword.fetch!(args, :submission_finality_margin)

    _ =
      Logger.info(
        "Starting BlockQueue at " <>
          "parent_height: #{inspect(parent_height)}, parent_start: #{inspect(parent_start)}, " <>
          "mined_child_block: #{inspect(mined_num)}, stored_child_top_block: #{inspect(stored_child_top_num)}"
      )

    range =
      Core.child_block_nums_to_init_with(mined_num, stored_child_top_num, child_block_interval, finality_threshold)

    {:ok, known_hashes} = OMG.DB.block_hashes(range)
    {:ok, {top_mined_hash, _}} = Eth.RootChain.get_child_chain(mined_num)
    _ = Logger.info("Starting BlockQueue, top_mined_hash: #{inspect(Encoding.to_hex(top_mined_hash))}")

    block_submit_every_nth = Keyword.fetch!(args, :block_submit_every_nth)

    {:ok, state} =
      case Core.new(
             mined_child_block_num: mined_num,
             known_hashes: Enum.zip(range, known_hashes),
             top_mined_hash: top_mined_hash,
             parent_height: parent_height,
             child_block_interval: child_block_interval,
             block_submit_every_nth: block_submit_every_nth,
             finality_threshold: finality_threshold
           ) do
        {:ok, _state} = result ->
          result

        {:error, reason} = error when reason in [:mined_hash_not_found_in_db, :contract_ahead_of_db] ->
          _ =
            log_init_error(
              known_hashes: known_hashes,
              parent_height: parent_height,
              mined_num: mined_num,
              stored_child_top_num: stored_child_top_num
            )

          error

        other ->
          other
      end

    interval = Keyword.fetch!(args, :block_queue_eth_height_check_interval_ms)
    {:ok, _} = :timer.send_interval(interval, self(), :check_ethereum_status)

    # `link: true` because we want the `BlockQueue` to restart and resubscribe, if the bus crashes
    :ok = OMG.Bus.subscribe("blocks", link: true)
    metrics_collection_interval = Keyword.fetch!(args, :metrics_collection_interval)
    {:ok, _} = :timer.send_interval(metrics_collection_interval, self(), :send_metrics)

    _ = Logger.info("Started #{inspect(__MODULE__)}")
    {:noreply, %Core{} = state}
  end

  def handle_info(:send_metrics, state) do
    :ok = :telemetry.execute([:process, __MODULE__], %{}, state)
    {:noreply, state}
  end

  @doc """
  Checks the status of the Ethereum root chain, the top mined child block number
  and status of State to decide what to do.

  `OMG.ChildChain.BlockQueue.Core` decides whether a new block should be formed or not.
  """
  def handle_info(:check_ethereum_status, %Core{} = state) do
    {:ok, ethereum_height} = EthereumHeight.get()
    {:ok, mined_blknum} = Eth.RootChain.get_mined_child_block()
    {_, is_empty_block} = OMG.State.get_status()

    _ = Logger.debug("Ethereum at \#'#{inspect(ethereum_height)}', mined child at \#'#{inspect(mined_blknum)}'")

    state1 =
      case Core.set_ethereum_status(state, ethereum_height, mined_blknum, is_empty_block) do
        {:do_form_block, state1} ->
          :ok = OMG.State.form_block()
          state1

        {:dont_form_block, state1} ->
          state1
      end

    submit_blocks(state1)
    {:noreply, state1}
  end

  @doc """
  Lines up a new block for submission. Presumably `OMG.State.form_block` wrote to the `:internal_event_bus` having
  formed a new child chain block.
  """
  def handle_info(
        {:internal_event_bus, :enqueue_block, %Block{number: block_number, hash: block_hash} = block},
        %Core{} = state
      ) do
    {:ok, parent_height} = EthereumHeight.get()
    state1 = Core.enqueue_block(state, block_hash, block_number, parent_height)
    _ = Logger.info("Enqueuing block num '#{inspect(block_number)}', hash '#{inspect(Encoding.to_hex(block_hash))}'")

    FreshBlocks.push(block)
    submit_blocks(state1)
    {:noreply, %Core{} = state1}
  end

  # private (server)

  @spec submit_blocks(Core.t()) :: :ok
  defp submit_blocks(%Core{} = state) do
    state
    |> Core.get_blocks_to_submit()
    |> Enum.each(&submit/1)
  end

  defp submit(%Core.BlockSubmission{hash: hash, nonce: nonce, gas_price: gas_price} = submission) do
    _ = Logger.debug("Submitting: #{inspect(submission)}")

    submit_result = Eth.submit_block(hash, nonce, gas_price)
    {:ok, newest_mined_blknum} = Eth.RootChain.get_mined_child_block()

    final_result = Core.process_submit_result(submission, submit_result, newest_mined_blknum)

    final_result =
      case final_result do
        {:error, _} = error ->
          _ = log_eth_node_error()
          error

        {:ok, txhash} ->
          GasAnalyzer.enqueue(txhash)
          :ok

        :ok ->
          :ok
      end

    :ok = final_result
  end

  defp log_init_error(fields) do
    config = Eth.Diagnostics.get_child_chain_config()
    fields = Keyword.update!(fields, :known_hashes, fn hashes -> Enum.map(hashes, &Encoding.to_hex/1) end)
    diagnostic = Enum.into(fields, %{config: config})

    _ =
      Logger.error(
        "The child chain might have not been wiped clean when starting a child chain from scratch: " <>
          "#{inspect(diagnostic)}. Check README.MD and follow the setting up child chain."
      )

    log_eth_node_error()
  end

  defp log_eth_node_error() do
    eth_node_diagnostics = Eth.Diagnostics.get_node_diagnostics()
    Logger.error("Ethereum operation failed, additional diagnostics: #{inspect(eth_node_diagnostics)}")
  end
end
